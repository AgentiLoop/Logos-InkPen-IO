import SwiftUI
import CoreGraphics
import simd

struct PasteboardBackgroundView: View {
    let pasteboardSize: CGSize
    let pasteboardOrigin: CGPoint
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            let x = pasteboardOrigin.x * zoomLevel + canvasOffset.x
            let y = pasteboardOrigin.y * zoomLevel + canvasOffset.y
            let w = pasteboardSize.width * zoomLevel
            let h = pasteboardSize.height * zoomLevel
            context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(.black.opacity(0.2)))
        }
    }
}

struct CanvasBackgroundView: View {
    let canvasSize: CGSize
    let backgroundColor: Color
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            let w = canvasSize.width * zoomLevel
            let h = canvasSize.height * zoomLevel
            context.fill(Path(CGRect(x: canvasOffset.x, y: canvasOffset.y, width: w, height: h)), with: .color(backgroundColor))
        }
    }
}

struct LayerCanvasView: View {
    let objectIDs: [UUID]
    let document: VectorDocument
    let documentURL: URL?
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let liveNudgeOffset: CGVector
    let liveScaleTransform: CGAffineTransform
    let dragPreviewTrigger: Bool
    let livePointPositions: [PointID: CGPoint]
    let liveHandlePositions: [HandleID: CGPoint]
    let fillDeltaOpacity: Double?
    let strokeDeltaOpacity: Double?
    let strokeDeltaWidth: Double?
    let colorDeltaColor: VectorColor?
    let colorDeltaOpacity: Double?

    @Binding var activeGradientDelta: VectorGradient?

    let isPanning: Bool
    let activeColorTarget: ColorTarget

    @Binding var textContentDelta: (id: UUID, content: String)?

    let fontSizeDelta: Double?
    let lineSpacingDelta: Double?
    let lineHeightDelta: Double?
    let letterSpacingDelta: Double?
    let imagePreviewQuality: Double
    let imageTileSize: Int
    let imageInterpolationQuality: CGInterpolationQuality
    let liveCornerRadii: [Double]
    let selectedShapeIDForCornerRadius: UUID?
    let layerUpdateTrigger: UInt?

    var appState = AppState.shared

    private func viewportRect(canvasSize: CGSize) -> CGRect {
        let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
        let sizeVec = SIMD2<Float>(Float(canvasSize.width), Float(canvasSize.height))
        let zoom = Float(zoomLevel)
        let docOrigin = -offsetVec / zoom
        let docSize = sizeVec / zoom
        return CGRect(
            x: CGFloat(docOrigin.x),
            y: CGFloat(docOrigin.y),
            width: CGFloat(docSize.x),
            height: CGFloat(docSize.y)
        )
    }

    private func culledObjects(canvasSize: CGSize) -> [VectorObject] {
        if isPanning {
            return objectIDs.compactMap { id in
                guard let object = document.snapshot.objects[id],
                      object.isVisible else { return nil }
                return object
            }
        }
        let viewport = viewportRect(canvasSize: canvasSize)
        return objectIDs.compactMap { id in
            guard let object = document.snapshot.objects[id],
                  object.isVisible else { return nil }
            if case .text = object.objectType {
                return object
            }
            let objectBounds = object.shape.bounds
            return objectBounds.intersectsSIMD(viewport) ? object : nil
        }
    }

    private var layerInfo: String {
        guard let firstID = objectIDs.first,

              let obj = document.snapshot.objects[firstID] else {
            return "Empty"
        }
        return "Layer[\(obj.layerIndex)]"
    }

    private func applyLivePositions(to shape: VectorShape) -> VectorShape {
        let shapeID = shape.id

        var hasLivePositions = false
        for pointID in livePointPositions.keys {
            if pointID.shapeID == shapeID {
                hasLivePositions = true
                break
            }
        }
        if !hasLivePositions {
            for handleID in liveHandlePositions.keys {
                if handleID.shapeID == shapeID {
                    hasLivePositions = true
                    break
                }
            }
        }
        guard hasLivePositions else { return shape }
        var modifiedShape = shape
        var modifiedElements = shape.path.elements
        for (pointID, livePosition) in livePointPositions where pointID.shapeID == shapeID {
            guard pointID.elementIndex < modifiedElements.count else { continue }
            let newPoint = VectorPoint(livePosition.x, livePosition.y)
            switch modifiedElements[pointID.elementIndex] {
            case .move(_):
                modifiedElements[pointID.elementIndex] = .move(to: newPoint)
            case .line(_):
                modifiedElements[pointID.elementIndex] = .line(to: newPoint)
            case .curve(_, let control1, let control2):
                modifiedElements[pointID.elementIndex] = .curve(to: newPoint, control1: control1, control2: control2)
            case .quadCurve(_, let control):
                modifiedElements[pointID.elementIndex] = .quadCurve(to: newPoint, control: control)
            case .close:
                break
            }
        }
        for (handleID, livePosition) in liveHandlePositions where handleID.shapeID == shapeID {
            guard handleID.elementIndex < modifiedElements.count else { continue }
            let newHandle = VectorPoint(livePosition.x, livePosition.y)
            switch modifiedElements[handleID.elementIndex] {
            case .curve(let to, let control1, let control2):
                if handleID.handleType == .control1 {
                    modifiedElements[handleID.elementIndex] = .curve(to: to, control1: newHandle, control2: control2)
                } else {
                    modifiedElements[handleID.elementIndex] = .curve(to: to, control1: control1, control2: newHandle)
                }
            case .quadCurve(let to, _):
                if handleID.handleType == .control1 {
                    modifiedElements[handleID.elementIndex] = .quadCurve(to: to, control: newHandle)
                }
            default:
                break
            }
        }
        modifiedShape.path = VectorPath(elements: modifiedElements)
        modifiedShape.updateBounds()
        return modifiedShape
    }

    private func applyLiveCornerRadii(to shape: VectorShape) -> VectorShape {
        guard !liveCornerRadii.isEmpty,
              selectedShapeIDForCornerRadius == shape.id else {
            return shape
        }
        var modifiedShape = shape
        modifiedShape.cornerRadii = liveCornerRadii
        let currentBounds = shape.path.cgPath.boundingBox
        let newPath = createRoundedRectPathWithIndividualCorners(
            rect: currentBounds,
            cornerRadii: liveCornerRadii
        )
        modifiedShape.path = newPath
        modifiedShape.updateBounds()
        return modifiedShape
    }

    var body: some View {
        Canvas { context, size in
            let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
            let zoom = Float(zoomLevel)
            let dragDelta = SIMD2<Float>(
                Float(dragPreviewDelta.x + liveNudgeOffset.dx),
                Float(dragPreviewDelta.y + liveNudgeOffset.dy)
            )
            let visibleObjects = culledObjects(canvasSize: size)
            _ = layerUpdateTrigger
            let baseTransform = CGAffineTransform.identity
                .translatedBy(x: CGFloat(offsetVec.x), y: CGFloat(offsetVec.y))
                .scaledBy(x: CGFloat(zoom), y: CGFloat(zoom))
            for object in visibleObjects {
                if case .guide = object.objectType { continue }
                let isSelected = selectedObjectIDs.contains(object.id)
                let isTextObject = if case .text = object.objectType { true } else { false }
                let hasLiveOffset = dragPreviewDelta != .zero || liveNudgeOffset != .zero
                if isSelected && hasLiveOffset {
                    context.transform = baseTransform
                        .translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                } else {
                    context.transform = baseTransform
                }
                let shapeTransform = (isSelected && !isTextObject) ? liveScaleTransform : .identity
                switch object.objectType {
                case .clipGroup(let clipGroupShape):
                    let memberShapes = document.resolveGroupMembers(clipGroupShape)
                    guard !memberShapes.isEmpty else { break }
                    let maskShape = memberShapes[0]
                    let contentShapes = Array(memberShapes.dropFirst())
                    let parentTransform = context.transform
                    if viewMode == .keyline {
                        if true {
                            let isMaskSelected = selectedObjectIDs.contains(maskShape.id)

                            let maskTransform = if isMaskSelected && dragPreviewDelta != .zero {
                                baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                            } else {
                                parentTransform
                            }
                            if maskShape.isVisible {
                                context.transform = maskTransform
                                let maskScaleTransform = isMaskSelected ? liveScaleTransform : .identity
                                let liveMaskShape = applyLiveCornerRadii(to: applyLivePositions(to: maskShape))
                                renderShape(liveMaskShape, context: &context, isSelected: isMaskSelected, scaleTransform: maskScaleTransform)
                            }
                            for contentShape in contentShapes {
                                guard contentShape.isVisible else { continue }
                                let isChildSelected = selectedObjectIDs.contains(contentShape.id)
                                let isChildText = contentShape.typography != nil

                                let contentTransform = if isChildSelected && dragPreviewDelta != .zero {
                                    baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                                } else {
                                    parentTransform
                                }
                                let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity
                                let liveContentShape = applyLiveCornerRadii(to: applyLivePositions(to: contentShape))
                                let liveMaskForClip = applyLiveCornerRadii(to: applyLivePositions(to: maskShape))

                                func renderKeylineClippedLeaf(_ shape: VectorShape, into lctx: inout GraphicsContext) {
                                    guard shape.isVisible else { return }
                                    if shape.isClippingGroup {
                                        let nestedMembers = document.resolveGroupMembers(shape)
                                        guard let nestedMask = nestedMembers.first else { return }
                                        let nestedContent = Array(nestedMembers.dropFirst())
                                        let liveNestedMask = applyLiveCornerRadii(to: applyLivePositions(to: nestedMask))
                                        let nestedMaskPath = liveNestedMask.cachedCGPath
                                        let savedTransform = lctx.transform
                                        if nestedMask.isVisible {
                                            renderShape(liveNestedMask, context: &lctx, isSelected: false, scaleTransform: .identity, maskShape: nil)
                                        }
                                        for contentShape in nestedContent {
                                            guard contentShape.isVisible else { continue }
                                            let liveContent = applyLiveCornerRadii(to: applyLivePositions(to: contentShape))
                                            lctx.drawLayer { innerContext in
                                                innerContext.transform = savedTransform
                                                if nestedMask.isVisible {
                                                    innerContext.clip(to: Path(nestedMaskPath), style: SwiftUI.FillStyle(eoFill: liveNestedMask.clipFillRule == .evenOdd))
                                                }
                                                renderKeylineClippedLeaf(liveContent, into: &innerContext)
                                            }
                                        }
                                        return
                                    }
                                    if shape.isGroupContainer {
                                        for m in document.resolveGroupMembers(shape) {
                                            renderKeylineClippedLeaf(m, into: &lctx)
                                        }
                                        return
                                    }
                                    if VectorText.from(shape) != nil {
                                        renderText(shape, context: &lctx, isSelected: false, liveScaleTransform: .identity, fontSizeDelta: 0, lineSpacingDelta: 0, lineHeightDelta: 0, letterSpacingDelta: 0, fillDeltaOpacity: 0, textContentDelta: nil, maskShape: nil)
                                    } else if hasImageData(shape) {
                                        renderImage(shape, context: &lctx, isSelected: false, scaleTransform: .identity, maskShape: nil, canvasSize: size)
                                    } else {
                                        renderShape(shape, context: &lctx, isSelected: false, scaleTransform: .identity, maskShape: nil)
                                    }
                                }
                                if hasImageData(liveContentShape) && !appState.cropImageBoxInKeyline {
                                    context.transform = contentTransform
                                    renderImage(liveContentShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil, canvasSize: size)
                                } else if !hasImageData(liveContentShape) && !appState.cropShapeClipInKeyline {
                                    context.transform = contentTransform
                                    if liveContentShape.isGroupContainer {
                                        renderKeylineClippedLeaf(liveContentShape, into: &context)
                                    } else if VectorText.from(liveContentShape) != nil {
                                        renderText(liveContentShape, context: &context, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, textContentDelta: textContentDelta, maskShape: nil)
                                    } else {
                                        renderShape(liveContentShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil)
                                    }
                                } else {
                                    context.drawLayer { layerContext in
                                        layerContext.transform = maskTransform
                                        let maskPath = liveMaskForClip.cachedCGPath
                                        layerContext.clip(to: Path(maskPath), style: SwiftUI.FillStyle(eoFill: liveMaskForClip.clipFillRule == .evenOdd))
                                        layerContext.transform = contentTransform
                                        if liveContentShape.isGroupContainer {
                                            renderKeylineClippedLeaf(liveContentShape, into: &layerContext)
                                        } else if VectorText.from(liveContentShape) != nil {
                                            renderText(liveContentShape, context: &layerContext, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, textContentDelta: textContentDelta, maskShape: nil)
                                        } else if hasImageData(liveContentShape) {
                                            renderImage(liveContentShape, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil, canvasSize: size)
                                        } else {
                                            renderShape(liveContentShape, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        let isMaskSelected = selectedObjectIDs.contains(maskShape.id)

                        let maskTransform = if isMaskSelected && dragPreviewDelta != .zero {
                            baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                        } else {
                            parentTransform
                        }
                        for contentShape in contentShapes {
                            guard contentShape.isVisible else { continue }
                            let isChildSelected = selectedObjectIDs.contains(contentShape.id)
                            let isChildText = contentShape.typography != nil

                            let contentTransform = if isChildSelected && dragPreviewDelta != .zero {
                                baseTransform.translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                            } else {
                                parentTransform
                            }
                            let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity
                            let liveContentColorMode = applyLivePositions(to: contentShape)
                            let liveMaskColorMode = applyLivePositions(to: maskShape)
                            context.drawLayer { layerContext in
                                layerContext.transform = maskTransform
                                if maskShape.isVisible {
                                    let maskPath = liveMaskColorMode.cachedCGPath
                                    layerContext.clip(to: Path(maskPath), style: SwiftUI.FillStyle(eoFill: liveMaskColorMode.clipFillRule == .evenOdd))
                                }
                                layerContext.transform = contentTransform

                                func renderClippedContent(_ shape: VectorShape, into lctx: inout GraphicsContext) {
                                    guard shape.isVisible else { return }
                                    if shape.isClippingGroup {
                                        let nestedMembers = document.resolveGroupMembers(shape)
                                        guard let nestedMask = nestedMembers.first else { return }
                                        let nestedContent = Array(nestedMembers.dropFirst())
                                        let liveNestedMask = applyLiveCornerRadii(to: applyLivePositions(to: nestedMask))
                                        let nestedMaskPath = liveNestedMask.cachedCGPath
                                        let savedTransform = lctx.transform
                                        for contentShape in nestedContent {
                                            guard contentShape.isVisible else { continue }
                                            let liveContent = applyLiveCornerRadii(to: applyLivePositions(to: contentShape))
                                            lctx.drawLayer { innerContext in
                                                innerContext.transform = savedTransform
                                                if nestedMask.isVisible {
                                                    innerContext.clip(to: Path(nestedMaskPath), style: SwiftUI.FillStyle(eoFill: liveNestedMask.clipFillRule == .evenOdd))
                                                }
                                                renderClippedContent(liveContent, into: &innerContext)
                                            }
                                        }
                                        return
                                    }
                                    if shape.isGroupContainer {
                                        let members = document.resolveGroupMembers(shape)
                                        for m in members {
                                            renderClippedContent(m, into: &lctx)
                                        }
                                        return
                                    }
                                    if VectorText.from(shape) != nil {
                                        renderText(shape, context: &lctx, isSelected: false, liveScaleTransform: .identity, fontSizeDelta: 0, lineSpacingDelta: 0, lineHeightDelta: 0, letterSpacingDelta: 0, fillDeltaOpacity: 0, textContentDelta: nil, maskShape: nil)
                                    } else if hasImageData(shape) {
                                        renderImage(shape, context: &lctx, isSelected: false, scaleTransform: .identity, maskShape: nil, canvasSize: size)
                                    } else {
                                        renderShape(shape, context: &lctx, isSelected: false, scaleTransform: .identity, maskShape: nil)
                                    }
                                }
                                if liveContentColorMode.isGroupContainer {
                                    renderClippedContent(liveContentColorMode, into: &layerContext)
                                } else if VectorText.from(liveContentColorMode) != nil {
                                    renderText(liveContentColorMode, context: &layerContext, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, textContentDelta: textContentDelta, maskShape: nil)
                                } else if hasImageData(liveContentColorMode) {
                                    renderImage(liveContentColorMode, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil, canvasSize: size)
                                } else {
                                    renderShape(liveContentColorMode, context: &layerContext, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: nil)
                                }
                            }
                        }
                    }
                case .group(let groupShape):
                    guard groupShape.isGroupContainer else { break }
                    let memberShapes = document.resolveGroupMembers(groupShape)
                    let parentTransform = context.transform

                    func renderGroupMembers(_ shapes: [VectorShape], parentXform: CGAffineTransform) {
                        for childShape in shapes {
                            guard childShape.isVisible else { continue }
                            let isChildSelected = selectedObjectIDs.contains(childShape.id)
                            let isChildText = childShape.typography != nil
                            if isChildSelected && dragPreviewDelta != .zero {
                                context.transform = baseTransform
                                    .translatedBy(x: CGFloat(dragDelta.x), y: CGFloat(dragDelta.y))
                            } else {
                                context.transform = parentXform
                            }
                            let childScaleTransform = (isChildSelected && !isChildText) ? liveScaleTransform : .identity

                            let maskShape: VectorShape? = {
                                guard let maskID = childShape.clippedByShapeID,

                                      let maskObject = document.snapshot.objects[maskID] else {
                                    return nil
                                }
                                return maskObject.shape
                            }()
                            let liveChildShape = applyLiveCornerRadii(to: applyLivePositions(to: childShape))
                            if liveChildShape.isClippingGroup {
                                let nestedMembers = document.resolveGroupMembers(liveChildShape)
                                guard let maskShape = nestedMembers.first else { continue }
                                let contentShapes = Array(nestedMembers.dropFirst())
                                let savedTransform = context.transform
                                let liveMaskForClip = applyLiveCornerRadii(to: applyLivePositions(to: maskShape))
                                let maskPath = liveMaskForClip.cachedCGPath
                                for contentShape in contentShapes {
                                    guard contentShape.isVisible else { continue }
                                    let isContentSelected = selectedObjectIDs.contains(contentShape.id)
                                    let contentScale: CGAffineTransform
                                    if isContentSelected, case .none = contentShape.typography {
                                        contentScale = liveScaleTransform
                                    } else {
                                        contentScale = .identity
                                    }
                                    let liveContent = applyLiveCornerRadii(to: applyLivePositions(to: contentShape))
                                    context.drawLayer { layerContext in
                                        layerContext.transform = savedTransform
                                        layerContext.clip(to: Path(maskPath), style: SwiftUI.FillStyle(eoFill: liveMaskForClip.clipFillRule == .evenOdd))
                                        if VectorText.from(liveContent) != nil {
                                            renderText(liveContent, context: &layerContext, isSelected: isContentSelected, liveScaleTransform: isContentSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, textContentDelta: textContentDelta, maskShape: nil)
                                        } else if hasImageData(liveContent) {
                                            renderImage(liveContent, context: &layerContext, isSelected: isContentSelected, scaleTransform: contentScale, maskShape: nil, canvasSize: size)
                                        } else {
                                            renderShape(liveContent, context: &layerContext, isSelected: isContentSelected, scaleTransform: contentScale, maskShape: nil)
                                        }
                                    }
                                }
                                continue
                            }
                            if liveChildShape.isGroupContainer {
                                let nestedMembers = document.resolveGroupMembers(liveChildShape)
                                renderGroupMembers(nestedMembers, parentXform: context.transform)
                            } else if VectorText.from(liveChildShape) != nil {
                                renderText(liveChildShape, context: &context, isSelected: isChildSelected, liveScaleTransform: isChildSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, textContentDelta: textContentDelta, maskShape: maskShape)
                            } else if hasImageData(liveChildShape) {
                                renderImage(liveChildShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: maskShape, canvasSize: size)
                            } else {
                                renderShape(liveChildShape, context: &context, isSelected: isChildSelected, scaleTransform: childScaleTransform, maskShape: maskShape)
                            }
                        }
                    }
                    renderGroupMembers(memberShapes, parentXform: parentTransform)
                case .shape(let shape), .warp(let shape), .clipMask(let shape), .guide(let shape):

                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,

                              let maskObject = document.snapshot.objects[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    let liveShape = applyLiveCornerRadii(to: applyLivePositions(to: shape))
                    renderShape(liveShape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape)
                case .image(let shape):

                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,

                              let maskObject = document.snapshot.objects[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    let liveImageShape = applyLiveCornerRadii(to: applyLivePositions(to: shape))
                    renderImage(liveImageShape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape, canvasSize: size)
                case .text(let shape):

                    let maskShape: VectorShape? = {
                        guard let maskID = shape.clippedByShapeID,

                              let maskObject = document.snapshot.objects[maskID] else {
                            return nil
                        }
                        return maskObject.shape
                    }()
                    let liveTextShape = applyLiveCornerRadii(to: applyLivePositions(to: shape))
                    renderText(liveTextShape, context: &context, isSelected: isSelected, liveScaleTransform: isSelected ? liveScaleTransform : .identity, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, fillDeltaOpacity: fillDeltaOpacity, strokeDeltaOpacity: strokeDeltaOpacity, strokeDeltaWidth: strokeDeltaWidth, textContentDelta: textContentDelta, maskShape: maskShape)
                }
            }
        }
    }

    private func calculateViewportBounds(size: CGSize) -> CGRect {
        let padding: CGFloat = 200.0
        let minX = (-canvasOffset.x - padding) / zoomLevel
        let minY = (-canvasOffset.y - padding) / zoomLevel
        let maxX = (size.width - canvasOffset.x + padding) / zoomLevel
        let maxY = (size.height - canvasOffset.y + padding) / zoomLevel
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func isObjectInViewport(_ bounds: CGRect, viewport: CGRect) -> Bool {
        return bounds.intersects(viewport)
    }

    private func isObjectInViewportSIMD(_ bounds: CGRect, viewport: CGRect) -> Bool {
        let objMin = SIMD2<Double>(bounds.minX, bounds.minY)
        let objMax = SIMD2<Double>(bounds.maxX, bounds.maxY)
        let vpMin = SIMD2<Double>(viewport.minX, viewport.minY)
        let vpMax = SIMD2<Double>(viewport.maxX, viewport.maxY)
        let overlapMin = objMax .>= vpMin
        let overlapMax = objMin .<= vpMax
        return all(overlapMin) && all(overlapMax)
    }

    private func renderShape(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, scaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil) {
        let hasVisibleFill = viewMode == .color && shape.fillStyle?.color != .clear
        let hasVisibleStroke = shape.strokeStyle?.color != .clear
        guard viewMode == .keyline || hasVisibleFill || hasVisibleStroke else { return }
        let cgPath: CGPath
        if scaleTransform != .identity {
            let mutablePath = CGMutablePath()
            mutablePath.addPath(shape.cachedCGPath, transform: scaleTransform)
            cgPath = mutablePath
        } else {
            cgPath = shape.cachedCGPath
        }
        if let maskShape = maskShape {
            context.drawLayer { layerContext in
                let maskPath = maskShape.cachedCGPath
                layerContext.clip(to: Path(maskPath), style: SwiftUI.FillStyle(eoFill: maskShape.clipFillRule == .evenOdd))
                if viewMode == .color, let fillStyle = shape.fillStyle {
                    let effectiveFillOpacity: Double
                    if let deltaOpacity = fillDeltaOpacity, selectedObjectIDs.contains(shape.id) {
                        effectiveFillOpacity = deltaOpacity
                    } else {
                        effectiveFillOpacity = fillStyle.opacity
                    }
                    if let gradient = activeGradientDelta, selectedObjectIDs.contains(shape.id), activeColorTarget == .fill {
                        let effectiveFillStyle = FillStyle(gradient: gradient, opacity: effectiveFillOpacity)
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &layerContext)
                    } else if let gradient = fillStyle.gradient {
                        let effectiveFillStyle = FillStyle(gradient: gradient, opacity: effectiveFillOpacity)
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &layerContext)
                    } else if fillStyle.color != .clear {
                        let effectiveFillColor: VectorColor
                        if let deltaColor = colorDeltaColor, selectedObjectIDs.contains(shape.id), activeColorTarget == .fill {
                            effectiveFillColor = deltaColor
                        } else {
                            effectiveFillColor = fillStyle.color
                        }
                        let useEvenOdd = shape.path.fillRule.cgPathFillRule == .evenOdd
                        layerContext.fill(Path(cgPath), with: .color(effectiveFillColor.color.opacity(effectiveFillOpacity)), style: SwiftUI.FillStyle(eoFill: useEvenOdd))
                    }
                }
                if viewMode == .keyline {
                    layerContext.stroke(Path(cgPath), with: .color(.black), lineWidth: 1.0 / zoomLevel)
                } else if let strokeStyle = shape.strokeStyle {
                    let isSelected = selectedObjectIDs.contains(shape.id)
                    let effectiveStrokeOpacity: Double
                    if let deltaOpacity = strokeDeltaOpacity, isSelected {
                        effectiveStrokeOpacity = deltaOpacity
                    } else {
                        effectiveStrokeOpacity = strokeStyle.opacity
                    }
                    let effectiveStrokeWidth: Double
                    if let deltaWidth = strokeDeltaWidth, isSelected {
                        effectiveStrokeWidth = deltaWidth
                    } else {
                        effectiveStrokeWidth = strokeStyle.width
                    }
                    if strokeStyle.placement == .center {
                        if let gradient = activeGradientDelta, isSelected, activeColorTarget == .stroke {
                            let effectiveStrokeStyle = StrokeStyle(
                                gradient: gradient,
                                width: effectiveStrokeWidth,
                                placement: strokeStyle.placement,
                                lineCap: strokeStyle.lineCap.cgLineCap,
                                lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                miterLimit: strokeStyle.miterLimit,
                                opacity: effectiveStrokeOpacity
                            )
                            renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: effectiveStrokeStyle, in: &layerContext)
                        } else if let gradient = strokeStyle.gradient {
                            let effectiveStrokeStyle = StrokeStyle(
                                gradient: gradient,
                                width: effectiveStrokeWidth,
                                placement: strokeStyle.placement,
                                lineCap: strokeStyle.lineCap.cgLineCap,
                                lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                miterLimit: strokeStyle.miterLimit,
                                opacity: effectiveStrokeOpacity
                            )
                            renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: effectiveStrokeStyle, in: &layerContext)
                        } else if strokeStyle.color != .clear {
                            let effectiveStrokeColor: VectorColor
                            if let delta = colorDeltaColor, isSelected, activeColorTarget == .stroke {
                                effectiveStrokeColor = delta
                            } else {
                                effectiveStrokeColor = strokeStyle.color
                            }
                            layerContext.stroke(
                                Path(cgPath),
                                with: .color(effectiveStrokeColor.color.opacity(effectiveStrokeOpacity)),
                                style: SwiftUI.StrokeStyle(
                                    lineWidth: effectiveStrokeWidth,
                                    lineCap: strokeStyle.lineCap.cgLineCap,
                                    lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                    miterLimit: strokeStyle.miterLimit
                                )
                            )
                        }
                    } else {
                        var effectiveStrokeStyle = strokeStyle
                        effectiveStrokeStyle.opacity = effectiveStrokeOpacity
                        effectiveStrokeStyle.width = effectiveStrokeWidth
                        renderStrokeWithPlacement(strokeStyle: effectiveStrokeStyle, path: cgPath, in: &layerContext)
                    }
                }
            }
        } else {
            if viewMode == .color, let fillStyle = shape.fillStyle {
                let effectiveFillOpacity: Double
                if let delta = fillDeltaOpacity, selectedObjectIDs.contains(shape.id) {
                    effectiveFillOpacity = delta
                } else {
                    effectiveFillOpacity = fillStyle.opacity
                }
                if let gradientDelta = activeGradientDelta, selectedObjectIDs.contains(shape.id), activeColorTarget == .fill {
                    let effectiveFillStyle = FillStyle(gradient: gradientDelta, opacity: effectiveFillOpacity)
                    renderGradientToContext(gradient: gradientDelta, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &context)
                } else if let gradient = fillStyle.gradient {
                    let effectiveFillStyle = FillStyle(gradient: gradient, opacity: effectiveFillOpacity)
                    renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: effectiveFillStyle, in: &context)
                } else if fillStyle.color != .clear {
                    let effectiveFillColor: VectorColor
                    if let delta = colorDeltaColor, selectedObjectIDs.contains(shape.id), activeColorTarget == .fill {
                        effectiveFillColor = delta
                    } else {
                        effectiveFillColor = fillStyle.color
                    }
                    let useEvenOdd = shape.path.fillRule.cgPathFillRule == .evenOdd
                    context.fill(Path(cgPath), with: .color(effectiveFillColor.color.opacity(effectiveFillOpacity)), style: SwiftUI.FillStyle(eoFill: useEvenOdd))
                }
            }
            if viewMode == .keyline {
                context.stroke(Path(cgPath), with: .color(.black), lineWidth: 1.0 / zoomLevel)
            } else if let strokeStyle = shape.strokeStyle {
                let isSelected = selectedObjectIDs.contains(shape.id)
                let effectiveStrokeOpacity: Double
                if let delta = strokeDeltaOpacity, isSelected {
                    effectiveStrokeOpacity = delta
                } else {
                    effectiveStrokeOpacity = strokeStyle.opacity
                }
                let effectiveStrokeWidth: Double
                if let delta = strokeDeltaWidth, isSelected {
                    effectiveStrokeWidth = delta
                } else {
                    effectiveStrokeWidth = strokeStyle.width
                }
                if strokeStyle.placement == .center {
                    if let gradientDelta = activeGradientDelta, isSelected, activeColorTarget == .stroke {
                        var effectiveStrokeStyle = strokeStyle
                        effectiveStrokeStyle.opacity = effectiveStrokeOpacity
                        effectiveStrokeStyle.width = effectiveStrokeWidth
                        renderGradientToContext(gradient: gradientDelta, path: cgPath, isStroke: true, strokeStyle: effectiveStrokeStyle, in: &context)
                    } else if let gradient = strokeStyle.gradient {
                        var effectiveStrokeStyle = strokeStyle
                        effectiveStrokeStyle.opacity = effectiveStrokeOpacity
                        effectiveStrokeStyle.width = effectiveStrokeWidth
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: effectiveStrokeStyle, in: &context)
                    } else if strokeStyle.color != .clear {
                        let effectiveStrokeColor: VectorColor
                        if let delta = colorDeltaColor, isSelected, activeColorTarget == .stroke {
                            effectiveStrokeColor = delta
                        } else {
                            effectiveStrokeColor = strokeStyle.color
                        }
                        context.stroke(
                            Path(cgPath),
                            with: .color(effectiveStrokeColor.color.opacity(effectiveStrokeOpacity)),
                            style: SwiftUI.StrokeStyle(
                                lineWidth: effectiveStrokeWidth,
                                lineCap: strokeStyle.lineCap.cgLineCap,
                                lineJoin: strokeStyle.lineJoin.cgLineJoin,
                                miterLimit: strokeStyle.miterLimit
                            )
                        )
                    }
                } else {
                    var effectiveStrokeStyle = strokeStyle
                    effectiveStrokeStyle.opacity = effectiveStrokeOpacity
                    effectiveStrokeStyle.width = effectiveStrokeWidth
                    renderStrokeWithPlacement(strokeStyle: effectiveStrokeStyle, path: cgPath, in: &context)
                }
            }
        }
    }

    private func renderStrokeWithPlacement(strokeStyle: StrokeStyle, path: CGPath, in context: inout GraphicsContext) {
        guard let outlinedPath = PathOperations.outlineStroke(path: path, strokeStyle: strokeStyle) else {
            return
        }
        if let gradient = strokeStyle.gradient {
            renderGradientToContext(gradient: gradient, path: outlinedPath, isStroke: false, strokeStyle: strokeStyle, fillStyle: nil, in: &context)
        } else if strokeStyle.color != .clear {
            context.fill(
                Path(outlinedPath),
                with: .color(strokeStyle.color.color.opacity(strokeStyle.opacity))
            )
        }
    }

    private func renderGradientToContext(gradient: VectorGradient, path: CGPath, isStroke: Bool, strokeStyle: StrokeStyle?, fillStyle: FillStyle? = nil, in context: inout GraphicsContext) {
        context.withCGContext { cgContext in
            cgContext.saveGState()
            if let fillStyle = fillStyle {
                cgContext.setAlpha(CGFloat(fillStyle.opacity))
            } else if let strokeStyle = strokeStyle {
                cgContext.setAlpha(CGFloat(strokeStyle.opacity))
            }
            let finalPath: CGPath
            if isStroke, let strokeStyle = strokeStyle {
                cgContext.setLineWidth(strokeStyle.width)
                cgContext.setLineCap(strokeStyle.lineCap.cgLineCap)
                cgContext.setLineJoin(strokeStyle.lineJoin.cgLineJoin)
                cgContext.setMiterLimit(strokeStyle.miterLimit)
                cgContext.addPath(path)
                cgContext.replacePathWithStrokedPath()
                finalPath = cgContext.path ?? path
            } else {
                finalPath = path
            }
            renderCGGradientFill(gradient: gradient, path: finalPath, in: cgContext)
            cgContext.restoreGState()
        }
    }

    private func renderCGGradientFill(gradient: VectorGradient, path: CGPath, in cgContext: CGContext) {
        cgContext.saveGState()
        let pathBounds = path.boundingBoxOfPath
        let colors: [CGColor] = gradient.stops.map { stop in
            if case .clear = stop.color {
                return stop.color.cgColor
            }
            return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }
        guard let cgGradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: locations
        ) else {
            cgContext.restoreGState()
            return
        }
        cgContext.addPath(path)
        cgContext.clip()
        switch gradient {
        case .linear(let linear):
            if linear.units == .userSpaceOnUse {
                let start = CGPoint(x: linear.startPoint.x, y: linear.startPoint.y)
                let end = CGPoint(x: linear.endPoint.x, y: linear.endPoint.y)
                cgContext.drawLinearGradient(
                    cgGradient,
                    start: start,
                    end: end,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            } else {
                let scale = CGFloat(linear.scaleX)
                let originX = linear.originPoint.x * scale
                let originY = linear.originPoint.y * scale
                let centerX = pathBounds.minX + pathBounds.width * originX
                let centerY = pathBounds.minY + pathBounds.height * originY
                let angle = CGFloat(linear.storedAngle * .pi / 180.0)
                let startVec = SIMD2<Double>(Double(linear.startPoint.x), Double(linear.startPoint.y))
                let endVec = SIMD2<Double>(Double(linear.endPoint.x), Double(linear.endPoint.y))
                let delta = endVec - startVec
                let length = simd_length(delta) * scale * max(pathBounds.width, pathBounds.height)
                let halfLength = length / 2
                let angleVec = SIMD2<Double>(cos(Double(angle)), sin(Double(angle)))
                let centerVec = SIMD2<Double>(Double(centerX), Double(centerY))
                let startVec2 = centerVec - angleVec * halfLength
                let endVec2 = centerVec + angleVec * halfLength
                let start = CGPoint(x: startVec2.x, y: startVec2.y)
                let end = CGPoint(x: endVec2.x, y: endVec2.y)
                cgContext.drawLinearGradient(
                    cgGradient,
                    start: start,
                    end: end,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
        case .radial(let radial):
            if radial.units == .userSpaceOnUse {
                let center = CGPoint(x: radial.centerPoint.x, y: radial.centerPoint.y)
                let focal = radial.focalPoint ?? center
                let radius = CGFloat(radial.radius)
                cgContext.drawRadialGradient(
                    cgGradient,
                    startCenter: focal,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: radius,
                    options: [.drawsAfterEndLocation]
                )
            } else {
                let center = CGPoint(
                    x: pathBounds.minX + pathBounds.width * radial.originPoint.x,
                    y: pathBounds.minY + pathBounds.height * radial.originPoint.y
                )
                cgContext.saveGState()
                cgContext.translateBy(x: center.x, y: center.y)
                cgContext.rotate(by: CGFloat(radial.angle * .pi / 180.0))
                cgContext.scaleBy(x: CGFloat(radial.scaleX), y: CGFloat(radial.scaleY))
                let focalPoint = radial.focalPoint.map { CGPoint(x: $0.x, y: $0.y) } ?? .zero
                let radius = max(pathBounds.width, pathBounds.height) * CGFloat(radial.radius)
                cgContext.drawRadialGradient(
                    cgGradient,
                    startCenter: focalPoint,
                    startRadius: 0,
                    endCenter: .zero,
                    endRadius: radius,
                    options: [.drawsAfterEndLocation]
                )
                cgContext.restoreGState()
            }
        }
        cgContext.restoreGState()
    }

    private func renderText(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, liveScaleTransform: CGAffineTransform = .identity, fontSizeDelta: Double? = nil, lineSpacingDelta: Double? = nil, lineHeightDelta: Double? = nil, letterSpacingDelta: Double? = nil, fillDeltaOpacity: Double? = nil, strokeDeltaOpacity: Double? = nil, strokeDeltaWidth: Double? = nil, textContentDelta: (id: UUID, content: String)? = nil, maskShape: VectorShape? = nil) {
        guard let vectorText = VectorText.from(shape) else { return }
        let effectiveContent: String
        if let delta = textContentDelta, delta.id == shape.id && !delta.content.isEmpty {
            effectiveContent = delta.content
        } else if !vectorText.content.isEmpty {
            effectiveContent = vectorText.content
        } else {
            return
        }
        context.withCGContext { cgContext in
            cgContext.saveGState()
            if let maskShape = maskShape {
                let maskPath = maskShape.cachedCGPath
                cgContext.addPath(maskPath)
                cgContext.clip(using: maskShape.clipFillRule)
            }
            let effectiveFillOpacity: Double
            if let delta = fillDeltaOpacity, isSelected {
                effectiveFillOpacity = delta
            } else {
                effectiveFillOpacity = vectorText.typography.fillOpacity
            }
            cgContext.setAlpha(CGFloat(effectiveFillOpacity))
            let effectiveFontSize: CGFloat
            let effectiveLineHeight: CGFloat
            let effectiveLineSpacing: CGFloat
            let effectiveLetterSpacing: CGFloat
            if isSelected {
                effectiveFontSize = if let delta = fontSizeDelta {
                    CGFloat(delta)
                } else {
                    vectorText.typography.fontSize
                }
                if let delta = lineHeightDelta {
                    effectiveLineHeight = CGFloat(delta)
                } else if let fontDelta = fontSizeDelta {
                    let lineHeightRatio = vectorText.typography.lineHeight / vectorText.typography.fontSize
                    effectiveLineHeight = CGFloat(fontDelta) * lineHeightRatio
                } else {
                    effectiveLineHeight = vectorText.typography.lineHeight
                }
                effectiveLineSpacing = if let delta = lineSpacingDelta {
                    CGFloat(delta)
                } else {
                    vectorText.typography.lineSpacing
                }
                effectiveLetterSpacing = if let delta = letterSpacingDelta {
                    CGFloat(delta)
                } else {
                    vectorText.typography.letterSpacing
                }
            } else {
                effectiveFontSize = vectorText.typography.fontSize
                effectiveLineHeight = vectorText.typography.lineHeight
                effectiveLineSpacing = vectorText.typography.lineSpacing
                effectiveLetterSpacing = vectorText.typography.letterSpacing
            }

            let nsFont: PlatformFont = {
                if let variant = vectorText.typography.fontVariant {
                    let fontManager = NSFontManager.shared
                    let members = fontManager.availableMembers(ofFontFamily: vectorText.typography.fontFamily) ?? []
                    for member in members {
                        if let postScriptName = member[0] as? String,
                           let displayName = member[1] as? String,
                           displayName == variant {
                            if let font = PlatformFont(name: postScriptName, size: effectiveFontSize) {
                                return font
                            }
                        }
                    }
                }
                return PlatformFont(name: vectorText.typography.fontFamily, size: effectiveFontSize) ?? PlatformFont.systemFont(ofSize: effectiveFontSize)
            }()
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
            paragraphStyle.lineSpacing = max(0, effectiveLineSpacing)
            paragraphStyle.minimumLineHeight = effectiveLineHeight
            paragraphStyle.maximumLineHeight = effectiveLineHeight
            let textColor = NSColor(cgColor: vectorText.typography.fillColor.cgColor) ?? .black
            let commonAttributes: [NSAttributedString.Key: Any] = [
                .font: nsFont,
                .paragraphStyle: paragraphStyle,
                .kern: effectiveLetterSpacing
            ]
            let attributedString = NSAttributedString(string: effectiveContent, attributes: commonAttributes)
            let textStorage = NSTextStorage(attributedString: attributedString)
            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)
            var textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
            var textPosition = vectorText.position
            if liveScaleTransform != .identity {
                let originalBounds = CGRect(
                    x: vectorText.position.x,
                    y: vectorText.position.y,
                    width: textBoxWidth,
                    height: vectorText.areaSize?.height ?? vectorText.bounds.height
                )
                let scaledBounds = originalBounds.applying(liveScaleTransform)
                textBoxWidth = scaledBounds.width
                textPosition = CGPoint(x: scaledBounds.minX, y: scaledBounds.minY)
            }
            let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: .greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = .byWordWrapping
            layoutManager.addTextContainer(textContainer)
            let textRange = NSRange(location: 0, length: effectiveContent.count)
            layoutManager.ensureGlyphs(forGlyphRange: textRange)
            layoutManager.ensureLayout(for: textContainer)
            var renderAttributes = commonAttributes
            renderAttributes[.foregroundColor] = textColor
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, lineUsedRect, _, lineRange, _ in
                let lineString = (effectiveContent as NSString).substring(with: lineRange)
                let lineAttribString = NSAttributedString(string: lineString, attributes: renderAttributes)

                var line = CTLineCreateWithAttributedString(lineAttribString)
                if vectorText.typography.alignment.nsTextAlignment == .justified,

                   let justifiedLine = CTLineCreateJustifiedLine(line, 1.0, lineUsedRect.width) {
                    line = justifiedLine
                }
                let glyphLocation = layoutManager.location(forGlyphAt: lineRange.location)
                let lineX: CGFloat
                switch vectorText.typography.alignment.nsTextAlignment {
                case .left, .justified:
                    lineX = textPosition.x + lineUsedRect.origin.x + glyphLocation.x
                case .center, .right:
                    lineX = textPosition.x + lineRect.origin.x + glyphLocation.x
                default:
                    lineX = textPosition.x + lineUsedRect.origin.x + glyphLocation.x
                }
                let lineY = textPosition.y + lineRect.origin.y + glyphLocation.y
                cgContext.saveGState()
                cgContext.textMatrix = textMatrix
                cgContext.textPosition = CGPoint(x: lineX, y: lineY)
                if vectorText.typography.hasStroke && vectorText.typography.strokeWidth > 0 {
                    guard let glyphRuns = CTLineGetGlyphRuns(line) as? [CTRun], !glyphRuns.isEmpty else {
                        cgContext.restoreGState()
                        return
                    }
                    let textPath = CGMutablePath()
                    for run in glyphRuns {
                        let glyphCount = CTRunGetGlyphCount(run)
                        let glyphs = UnsafeMutablePointer<CGGlyph>.allocate(capacity: glyphCount)
                        let positions = UnsafeMutablePointer<CGPoint>.allocate(capacity: glyphCount)
                        CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), glyphs)
                        CTRunGetPositions(run, CFRangeMake(0, glyphCount), positions)
                        let attributes = CTRunGetAttributes(run) as NSDictionary
                        if let rawFont = attributes[kCTFontAttributeName],
                           CFGetTypeID(rawFont as CFTypeRef) == CTFontGetTypeID() {
                            let font = rawFont as! CTFont
                            for i in 0..<glyphCount {
                                if let glyphPath = CTFontCreatePathForGlyph(font, glyphs[i], nil) {
                                    let transform = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                                    textPath.addPath(glyphPath, transform: transform)
                                }
                            }
                        }
                        glyphs.deallocate()
                        positions.deallocate()
                    }
                    let effectiveStrokeWidth: Double
                    if let delta = strokeDeltaWidth, isSelected {
                        effectiveStrokeWidth = delta
                    } else {
                        effectiveStrokeWidth = vectorText.typography.strokeWidth
                    }
                    let effectiveStrokeOpacity: Double
                    if let delta = strokeDeltaOpacity, isSelected {
                        effectiveStrokeOpacity = delta
                    } else {
                        effectiveStrokeOpacity = vectorText.typography.strokeOpacity
                    }
                    cgContext.saveGState()
                    cgContext.translateBy(x: lineX, y: lineY)
                    cgContext.concatenate(textMatrix)
                    cgContext.addPath(textPath)
                    cgContext.setFillColor(textColor.cgColor)
                    cgContext.setAlpha(CGFloat(effectiveFillOpacity))
                    cgContext.fillPath()
                    cgContext.addPath(textPath)
                    let strokeColor = NSColor(cgColor: vectorText.typography.strokeColor.cgColor) ?? .black
                    cgContext.setStrokeColor(strokeColor.cgColor)
                    cgContext.setLineWidth(effectiveStrokeWidth)
                    cgContext.setLineJoin(vectorText.typography.strokeLineJoin.cgLineJoin)
                    cgContext.setLineCap(.butt)
                    cgContext.setAlpha(CGFloat(effectiveStrokeOpacity))
                    cgContext.strokePath()
                    cgContext.restoreGState()
                } else {
                    CTLineDraw(line, cgContext)
                }
                cgContext.restoreGState()
            }
            cgContext.restoreGState()
        }
    }

    private func hasImageData(_ shape: VectorShape) -> Bool {
        return shape.embeddedImageData != nil || shape.linkedImagePath != nil || shape.linkedImageBookmarkData != nil
    }

    private func resolveLinkedImage(linkedPath: String, documentURL: URL?, bookmarkData: Data?, shapeID: UUID) -> CGImage? {
        func loadFromURL(_ url: CFURL) -> CGImage? {
            guard let imageSource = CGImageSourceCreateWithURL(url, nil),
                  let sourceCGImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                return nil
            }
            let width = sourceCGImage.width
            let height = sourceCGImage.height
            let colorSpace = sourceCGImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = sourceCGImage.bitmapInfo
            if let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) {
                ctx.draw(sourceCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
                return ctx.makeImage() ?? sourceCGImage
            }
            return sourceCGImage
        }
        if let bookmarkData = bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI, .withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                ImageContentRegistry.dequarantine(url)
                if let image = loadFromURL(url as CFURL) { return image }
            }
        }
        let fileURL = URL(fileURLWithPath: linkedPath)
        ImageContentRegistry.dequarantine(fileURL)
        return loadFromURL(fileURL as CFURL)
    }
    private static var renderImageCallCount = 0
    private static var lastRenderImageMemMB = 0

    private func renderImage(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, scaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil, canvasSize: CGSize) {
        Self.renderImageCallCount += 1
        if Self.renderImageCallCount % 60 == 1 {
            let mb = MemoryDiag.processMemoryMB()
            let delta = mb - Self.lastRenderImageMemMB
            if Self.lastRenderImageMemMB > 0 && delta > 5 {
            }
            Self.lastRenderImageMemMB = mb
        }
        let pathBounds = shape.path.cgPath.boundingBoxOfPath

        var renderBounds = pathBounds
        if scaleTransform != .identity {
            renderBounds = pathBounds.applying(scaleTransform)
        }
        if !shape.transform.isIdentity {
            renderBounds = renderBounds.applying(shape.transform)
        }

        if viewMode == .keyline {
            let lineWidth = 1.0 / zoomLevel
            var boxPath = Path()
            boxPath.addRect(renderBounds)
            boxPath.move(to: CGPoint(x: renderBounds.minX, y: renderBounds.minY))
            boxPath.addLine(to: CGPoint(x: renderBounds.maxX, y: renderBounds.maxY))
            boxPath.move(to: CGPoint(x: renderBounds.maxX, y: renderBounds.minY))
            boxPath.addLine(to: CGPoint(x: renderBounds.minX, y: renderBounds.maxY))
            if let maskShape = maskShape {
                if appState.cropImageBoxInKeyline {
                    context.drawLayer { layerCtx in
                        layerCtx.clip(to: Path(maskShape.cachedCGPath), style: SwiftUI.FillStyle(eoFill: maskShape.clipFillRule == .evenOdd))
                        layerCtx.stroke(boxPath, with: .color(.black), lineWidth: lineWidth)
                    }
                } else {
                    context.stroke(boxPath, with: .color(.black), lineWidth: lineWidth)
                }
                context.stroke(Path(maskShape.cachedCGPath), with: .color(.black), lineWidth: lineWidth)
            } else {
                context.stroke(boxPath, with: .color(.black), lineWidth: lineWidth)
            }
            return
        }

        let image: CGImage
        if let cachedImage = document.imageStorage[shape.id] {
            image = cachedImage
        } else {
            let sourceCGImage: CGImage?
            if let imageData = shape.embeddedImageData,
               let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),

               let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                sourceCGImage = cgImage
            } else if let linkedPath = shape.linkedImagePath,
                      let resolvedImage = resolveLinkedImage(
                          linkedPath: linkedPath,
                          documentURL: documentURL,
                          bookmarkData: shape.linkedImageBookmarkData,
                          shapeID: shape.id
                      ) {
                sourceCGImage = resolvedImage
            } else {
                return
            }
            guard let cgImage = sourceCGImage else {
                return
            }
            let finalImage: CGImage
            if imagePreviewQuality < 1.0 {
                let maxDimension = max(cgImage.width, cgImage.height)
                let targetSize = Int(Double(maxDimension) * imagePreviewQuality)
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                let aspectRatio = Double(cgImage.width) / Double(cgImage.height)
                let targetWidth: Int
                let targetHeight: Int
                if cgImage.width >= cgImage.height {
                    targetWidth = targetSize
                    targetHeight = Int(Double(targetSize) / aspectRatio)
                } else {
                    targetHeight = targetSize
                    targetWidth = Int(Double(targetSize) * aspectRatio)
                }
                guard let downsampleContext = CGContext(
                    data: nil,
                    width: targetWidth,
                    height: targetHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: targetWidth * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                ) else {
                    finalImage = cgImage
                    image = finalImage
                    return
                }
                downsampleContext.interpolationQuality = imageInterpolationQuality
                downsampleContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
                finalImage = downsampleContext.makeImage() ?? cgImage
            } else {
                finalImage = cgImage
            }
            document.imageStorage[shape.id] = finalImage
            image = finalImage
        }
        let imageHash = ObjectIdentifier(image).hashValue
        let lastHash = document.lastDrawnImageHash[shape.id]
        if lastHash == imageHash {
        } else {
            document.lastDrawnImageHash[shape.id] = imageHash
        }
        context.withCGContext { cgContext in
            cgContext.saveGState()
            if let maskShape = maskShape {
                let maskPath = maskShape.cachedCGPath
                cgContext.addPath(maskPath)
                cgContext.clip(using: maskShape.clipFillRule)
            }
            cgContext.setAlpha(CGFloat(shape.opacity))
            cgContext.translateBy(x: renderBounds.minX, y: renderBounds.maxY)
            cgContext.scaleBy(x: 1.0, y: -1.0)
            cgContext.interpolationQuality = imageInterpolationQuality
            cgContext.draw(image, in: CGRect(origin: .zero, size: renderBounds.size))
            cgContext.restoreGState()
        }
    }
}

struct IsolatedLayerView: View {
    let objectIDs: [UUID]
    let document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let liveNudgeOffset: CGVector
    let dragPreviewTrigger: Bool
    let liveScaleTransform: CGAffineTransform
    let layerOpacity: Double
    let layerBlendMode: BlendMode
    let livePointPositions: [PointID: CGPoint]
    let liveHandlePositions: [HandleID: CGPoint]
    let fillDeltaOpacity: Double?
    let strokeDeltaOpacity: Double?
    let strokeDeltaWidth: Double?
    let colorDeltaColor: VectorColor?
    let colorDeltaOpacity: Double?

    @Binding var activeGradientDelta: VectorGradient?

    let activeColorTarget: ColorTarget

    @Binding var textContentDelta: (id: UUID, content: String)?

    let fontSizeDelta: Double?
    let lineSpacingDelta: Double?
    let lineHeightDelta: Double?
    let letterSpacingDelta: Double?
    let imagePreviewQuality: Double
    let imageTileSize: Int
    let imageInterpolationQuality: CGInterpolationQuality
    let liveCornerRadii: [Double]
    let selectedShapeIDForCornerRadius: UUID?
    let layerUpdateTrigger: UInt
    let isPanning: Bool

    private var editingTextShapes: [(id: UUID, dragDelta: CGPoint)] {
        guard document.viewState.currentTool == .font else {
            return []
        }
        var shapes: [(id: UUID, dragDelta: CGPoint)] = []
        for objectID in objectIDs {
            guard let freshObject = document.snapshot.objects[objectID],
                  freshObject.isVisible else { continue }
            switch freshObject.objectType {
            case .text(let shape):
                if let vectorText = VectorText.from(shape),
                   vectorText.getState(in: document) == .editing {
                    let isSelected = selectedObjectIDs.contains(shape.id)
                    let delta = isSelected ? dragPreviewDelta : .zero
                    shapes.append((id: shape.id, dragDelta: delta))
                }
            case .group(let groupShape):
                for childShape in groupShape.groupedShapes {
                    if childShape.typography != nil {
                    }
                    guard childShape.isVisible else { continue }
                    if let vectorText = VectorText.from(childShape),
                       vectorText.getState(in: document) == .editing {
                        let isChildSelected = selectedObjectIDs.contains(childShape.id)
                        let isParentSelected = selectedObjectIDs.contains(freshObject.id)
                        let delta = (isChildSelected || isParentSelected) ? dragPreviewDelta : .zero
                        shapes.append((id: childShape.id, dragDelta: delta))
                    }
                }
            default:
                break
            }
        }
        return shapes
    }

    var body: some View {
        ZStack {
            LayerCanvasView(
                objectIDs: objectIDs,
                document: document,
                documentURL: nil,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                selectedObjectIDs: selectedObjectIDs,
                viewMode: viewMode,
                dragPreviewDelta: dragPreviewDelta,
                liveNudgeOffset: liveNudgeOffset,
                liveScaleTransform: liveScaleTransform,
                dragPreviewTrigger: dragPreviewTrigger,
                livePointPositions: livePointPositions,
                liveHandlePositions: liveHandlePositions,
                fillDeltaOpacity: fillDeltaOpacity,
                strokeDeltaOpacity: strokeDeltaOpacity,
                strokeDeltaWidth: strokeDeltaWidth,
                colorDeltaColor: colorDeltaColor,
                colorDeltaOpacity: colorDeltaOpacity,
                activeGradientDelta: $activeGradientDelta,
                isPanning: isPanning,
                activeColorTarget: activeColorTarget,
                textContentDelta: $textContentDelta,
                fontSizeDelta: fontSizeDelta,
                lineSpacingDelta: lineSpacingDelta,
                lineHeightDelta: lineHeightDelta,
                letterSpacingDelta: letterSpacingDelta,
                imagePreviewQuality: imagePreviewQuality,
                imageTileSize: imageTileSize,
                imageInterpolationQuality: imageInterpolationQuality,
                liveCornerRadii: liveCornerRadii,
                selectedShapeIDForCornerRadius: selectedShapeIDForCornerRadius,
                layerUpdateTrigger: layerUpdateTrigger
            )
            ForEach(editingTextShapes, id: \.id) { textInfo in
                ProfessionalTextCanvas(
                    document: document,
                    textObjectID: textInfo.id,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    dragPreviewDelta: textInfo.dragDelta,
                    dragPreviewTrigger: dragPreviewTrigger,
                    viewMode: viewMode,
                    letterSpacingDelta: letterSpacingDelta,
                    lineHeightDelta: lineHeightDelta,
                    fontSizeDelta: fontSizeDelta,
                    lineSpacingDelta: lineSpacingDelta,
                    textContentDelta: $textContentDelta
                )
                .allowsHitTesting(document.viewState.currentTool == .font)
            }
        }
        .opacity(layerOpacity)
        .blendMode(layerBlendMode.swiftUIBlendMode)
    }
}

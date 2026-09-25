import SwiftUI

enum TransformOrigin: String, CaseIterable {
    case topLeft = "Top Left"
    case topCenter = "Top Center"
    case topRight = "Top Right"
    case middleLeft = "Middle Left"
    case center = "Center"
    case middleRight = "Middle Right"
    case bottomLeft = "Bottom Left"
    case bottomCenter = "Bottom Center"
    case bottomRight = "Bottom Right"

    var point: CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: 0, y: 0)
        case .topCenter: return CGPoint(x: 0.5, y: 0)
        case .topRight: return CGPoint(x: 1, y: 0)
        case .middleLeft: return CGPoint(x: 0, y: 0.5)
        case .center: return CGPoint(x: 0.5, y: 0.5)
        case .middleRight: return CGPoint(x: 1, y: 0.5)
        case .bottomLeft: return CGPoint(x: 0, y: 1)
        case .bottomCenter: return CGPoint(x: 0.5, y: 1)
        case .bottomRight: return CGPoint(x: 1, y: 1)
        }
    }
}

struct NinePointOriginSelector: View {

    @Binding var selectedOrigin: TransformOrigin
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3) { row in
                HStack(spacing: 2) {
                    ForEach(0..<3) { col in
                        let origin = originForPosition(row: row, col: col)
                        ZStack {
                            Rectangle()
                                .fill(selectedOrigin == origin ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                                .frame(width: 10, height: 10)
                            Circle()
                                .fill(selectedOrigin == origin ? Color.red : Color.gray.opacity(0.5))
                                .frame(width: selectedOrigin == origin ? 6 : 4, height: selectedOrigin == origin ? 6 : 4)
                        }
                        .frame(width: 10, height: 10)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedOrigin = origin
                        }
                    }
                }
            }
        }
        .frame(width: 38, height: 38)
        .background(Color.platformControlBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .help("Transform origin: \(selectedOrigin.rawValue)")
    }

    private func originForPosition(row: Int, col: Int) -> TransformOrigin {
        let index = row * 3 + col
        return TransformOrigin.allCases[index]
    }
}

struct TransformationControls: View {

    @ObservedObject var document: VectorDocument

    @Binding var liveDragOffset: CGPoint
    @Binding var liveScaleDimensions: CGSize

    @State private var keepProportions: Bool = false
    @State private var xValue: String = ""
    @State private var yValue: String = ""
    @State private var widthValue: String = ""
    @State private var heightValue: String = ""
    @State private var aspectRatio: CGFloat = 1.0
    @State private var scaleXValue: String = "100"
    @State private var scaleYValue: String = "100"
    @State private var linkScale: Bool = true
    @State private var rotationValue: String = "0"
    private var transformOriginBinding: Binding<TransformOrigin> {
        Binding(
            get: { document.viewState.transformOrigin },
            set: { newOrigin in
                document.viewState.transformOrigin = newOrigin
                for objectID in document.viewState.selectedObjectIDs {
                    document.updateShapeByID(objectID, silent: false) { shape in
                        shape.transformOrigin = newOrigin
                    }
                }
            }
        )
    }

    var hasSelection: Bool {
        !document.viewState.PublishedSelectedObjectIDs.isEmpty
    }

    private var currentUnit: MeasurementUnit {
        document.settings.unit
    }

    private var unitSuffix: String {
        currentUnit.abbreviation
    }

    var body: some View {
        HStack(spacing: 6) {
            NinePointOriginSelector(selectedOrigin: transformOriginBinding)
                .disabled(!hasSelection)
                .opacity(hasSelection ? 1.0 : 0.5)
            HStack(spacing: 1) {
                Text("X:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize()
                TextField("", text: $xValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 55)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        applyTransformation()
                    }
                Text(unitSuffix)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 20, alignment: .leading)
            }
            HStack(spacing: 1) {
                Text("Y:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize()
                TextField("", text: $yValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 55)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        applyTransformation()
                    }
                Text(unitSuffix)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 20, alignment: .leading)
            }
            HStack(spacing: 1) {
                Text("W:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize()
                TextField("", text: $widthValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 55)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        if keepProportions {
                            updateHeightProportionally()
                        }
                        applyTransformation()
                    }
                    .onChange(of: widthValue) { _, _ in
                        if keepProportions && !widthValue.isEmpty {
                            updateHeightProportionally()
                        }
                    }
                Text(unitSuffix)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 20, alignment: .leading)
            }
            HStack(spacing: 1) {
                Text("H:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize()
                TextField("", text: $heightValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 55)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        if keepProportions {
                            updateWidthProportionally()
                        }
                        applyTransformation()
                    }
                    .onChange(of: heightValue) { _, _ in
                        if keepProportions && !heightValue.isEmpty {
                            updateWidthProportionally()
                        }
                    }
                Text(unitSuffix)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 20, alignment: .leading)
            }
            Button(action: {
                keepProportions.toggle()
            }) {
                Image(systemName: keepProportions ? "lock.fill" : "lock.open.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundColor(keepProportions ? .orange : Color(PlatformColor.systemBlue))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.platformControlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(keepProportions ? Color.orange.opacity(0.4) : Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: keepProportions ?
                Color(.displayP3, red: 0.0, green: 0.478, blue: 1.0).opacity(0.3) :
                Color(.displayP3, red: 1.0, green: 0.584, blue: 0.0).opacity(0.3),
                radius: 2)
            .disabled(!hasSelection)
            .opacity(hasSelection ? 1.0 : 0.3)
            .help(keepProportions ? "⚠️ Proportions LOCKED - Width/Height ratio maintained" : "✓ Proportions UNLOCKED - Free resize")
            Divider()
                .frame(height: 24)
            HStack(spacing: 2) {
                Text("SX:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $scaleXValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 40)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        applyScale()
                    }
                    .onChange(of: scaleXValue) { _, newValue in
                        if linkScale, let scale = Double(newValue) {
                            scaleYValue = String(format: "%.1f", scale)
                        }
                    }
                Text("%")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 12, alignment: .leading)
            }
            HStack(spacing: 2) {
                Text("SY:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $scaleYValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 40)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        applyScale()
                    }
                    .onChange(of: scaleYValue) { _, newValue in
                        if linkScale, let scale = Double(newValue) {
                            scaleXValue = String(format: "%.1f", scale)
                        }
                    }
                Text("%")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 12, alignment: .leading)
            }
            Button(action: {
                linkScale.toggle()
            }) {
                Image(systemName: linkScale ? "link" : "link.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundColor(linkScale ? .orange : Color(PlatformColor.systemBlue))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.platformControlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(linkScale ? Color.orange.opacity(0.4) : Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: linkScale ?
                Color(.displayP3, red: 1.0, green: 0.584, blue: 0.0).opacity(0.3) :
                Color(.displayP3, red: 0.0, green: 0.478, blue: 1.0).opacity(0.3),
                radius: 2)
            .disabled(!hasSelection)
            .opacity(hasSelection ? 1.0 : 0.3)
            .help(linkScale ? "⚠️ Scale LINKED - X and Y scale together" : "✓ Scale UNLINKED - Independent X/Y scaling")
            Divider()
                .frame(height: 24)
            HStack(spacing: 2) {
                Text("R:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("", text: $rotationValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 40)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.trailing)
                    .disabled(!hasSelection)
                    .onSubmit {
                        applyRotation()
                    }
                Text("°")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 12, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .onAppear {
            syncTransformOriginFromSelection()
            updateValuesFromSelection()
        }
        .onChange(of: document.viewState.PublishedSelectedObjectIDs) { _, _ in
            syncTransformOriginFromSelection()
            updateValuesFromSelection()
        }
        .onChange(of: document.viewState.transformOrigin) { _, _ in
            updateValuesFromSelection()
        }
        .onChange(of: document.viewState.objectPositionUpdateTrigger) { _, _ in
            if !document.isHandleScalingActive {
                updateValuesFromSelection()
            }
        }
        .onChange(of: liveDragOffset) { _, _ in
            updatePositionOnly()
        }
        .onChange(of: liveScaleDimensions) { _, _ in
            if document.isHandleScalingActive && liveScaleDimensions != .zero {
                widthValue = currentUnit.format(currentUnit.fromPoints(liveScaleDimensions.width))
                heightValue = currentUnit.format(currentUnit.fromPoints(liveScaleDimensions.height))
            }
        }
        .onChange(of: document.settings.unit) { _, _ in
            updateValuesFromSelection()
        }
    }

    private func syncTransformOriginFromSelection() {
        guard let firstID = document.viewState.selectedObjectIDs.first,

              let obj = document.snapshot.objects[firstID] else {
            return
        }
        if let objectOrigin = obj.shape.transformOrigin {
            if document.viewState.transformOrigin != objectOrigin {
                document.viewState.transformOrigin = objectOrigin
            }
        }
    }

    private func updatePositionOnly() {
        let bounds = document.cachedSelectionBounds ?? getSelectionBounds()
        guard let bounds = bounds else {
            xValue = ""
            yValue = ""
            return
        }
        let origin = document.viewState.transformOrigin.point
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let xInPoints = bounds.minX + bounds.width * origin.x + liveDragOffset.x - pageOrigin.x
        let yInPoints = bounds.minY + bounds.height * origin.y + liveDragOffset.y - pageOrigin.y
        xValue = currentUnit.format(currentUnit.fromPoints(xInPoints))
        yValue = currentUnit.format(currentUnit.fromPoints(yInPoints))
    }

    private func updateValuesFromSelection() {
        guard let bounds = getSelectionBounds() else {
            xValue = ""
            yValue = ""
            widthValue = ""
            heightValue = ""
            aspectRatio = 1.0
            return
        }
        let origin = document.viewState.transformOrigin.point
        let pageOrigin = document.settings.pageOrigin ?? .zero
        let xInPoints = bounds.minX + bounds.width * origin.x - pageOrigin.x
        let yInPoints = bounds.minY + bounds.height * origin.y - pageOrigin.y
        xValue = currentUnit.format(currentUnit.fromPoints(xInPoints))
        yValue = currentUnit.format(currentUnit.fromPoints(yInPoints))
        widthValue = currentUnit.format(currentUnit.fromPoints(bounds.width))
        heightValue = currentUnit.format(currentUnit.fromPoints(bounds.height))
        aspectRatio = bounds.height > 0 ? bounds.width / bounds.height : 1.0
    }

    private func updateHeightProportionally() {
        guard let width = Double(widthValue), aspectRatio > 0 else { return }
        let newHeight = width / aspectRatio
        heightValue = currentUnit.format(newHeight)
    }

    private func updateWidthProportionally() {
        guard let height = Double(heightValue), aspectRatio > 0 else { return }
        let newWidth = height * aspectRatio
        widthValue = currentUnit.format(newWidth)
    }

    private func transformPoint(_ point: CGPoint, currentOrigin: CGPoint, newOrigin: CGPoint, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        let dx = point.x - currentOrigin.x
        let dy = point.y - currentOrigin.y
        let scaledX = dx * scaleX
        let scaledY = dy * scaleY
        return CGPoint(x: scaledX + newOrigin.x, y: scaledY + newOrigin.y)
    }

    private func getSelectionBounds() -> CGRect? {
        guard !document.viewState.selectedObjectIDs.isEmpty else { return nil }
        var combinedBounds: CGRect?
        for vectorObject in document.snapshot.objects.values {
            switch vectorObject.objectType {
            case .text(let shape):
                if document.viewState.selectedObjectIDs.contains(shape.id) {
                    let position = shape.textPosition ?? CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                    let shapeBounds = CGRect(
                        x: position.x,
                        y: position.y,
                        width: shape.bounds.width,
                        height: shape.bounds.height
                    )
                    combinedBounds = combinedBounds.map { $0.union(shapeBounds) } ?? shapeBounds
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape),
                 .guide(let shape):
                if document.viewState.selectedObjectIDs.contains(shape.id) {
                    let shapeBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                    combinedBounds = combinedBounds.map { $0.union(shapeBounds) } ?? shapeBounds
                }
            }
        }
        return combinedBounds
    }

    private func applyTransformation() {
        guard let currentBounds = getSelectionBounds(),
              let newXInUnit = Double(xValue),
              let newYInUnit = Double(yValue),
              let newWidthInUnit = Double(widthValue),
              let newHeightInUnit = Double(heightValue),
              newWidthInUnit > 0,
              newHeightInUnit > 0 else { return }
        let newX = currentUnit.toPoints(newXInUnit)
        let newY = currentUnit.toPoints(newYInUnit)
        let newWidth = currentUnit.toPoints(newWidthInUnit)
        let newHeight = currentUnit.toPoints(newHeightInUnit)
        document.modifySelectedShapesWithUndo(
            preCapture: {
                let originOffset = document.viewState.transformOrigin.point
                let currentOriginX = currentBounds.minX + currentBounds.width * originOffset.x
                let currentOriginY = currentBounds.minY + currentBounds.height * originOffset.y
                let pageOrigin = document.settings.pageOrigin ?? .zero
                let newOriginX = newX + pageOrigin.x
                let newOriginY = newY + pageOrigin.y
                let scaleX = newWidth / currentBounds.width
                let scaleY = newHeight / currentBounds.height
                for objectID in document.viewState.selectedObjectIDs {
                    if let newVectorObject = document.snapshot.objects[objectID],
                       case .shape(var shape) = newVectorObject.objectType {
                        if shape.isGroupContainer {
                            var transformedGroupedShapes: [VectorShape] = []
                            for var groupedShape in shape.groupedShapes {
                                var transformedElements: [PathElement] = []
                                for element in groupedShape.path.elements {
                                    switch element {
                                    case .move(let to):
                                        let pt = to.cgPoint
                                        let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.move(to: VectorPoint(newPt)))
                                    case .line(let to):
                                        let pt = to.cgPoint
                                        let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.line(to: VectorPoint(newPt)))
                                    case .curve(let to, let control1, let control2):
                                        let toPt = to.cgPoint
                                        let c1Pt = control1.cgPoint
                                        let c2Pt = control2.cgPoint
                                        let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        let newC1 = transformPoint(c1Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        let newC2 = transformPoint(c2Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.curve(to: VectorPoint(newTo),
                                                                         control1: VectorPoint(newC1),
                                                                         control2: VectorPoint(newC2)))
                                    case .quadCurve(let to, let control):
                                        let toPt = to.cgPoint
                                        let cPt = control.cgPoint
                                        let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                  newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                  scaleX: scaleX, scaleY: scaleY)
                                        let newC = transformPoint(cPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                                newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                                scaleX: scaleX, scaleY: scaleY)
                                        transformedElements.append(.quadCurve(to: VectorPoint(newTo),
                                                                             control: VectorPoint(newC)))
                                    case .close:
                                        transformedElements.append(.close)
                                    }
                                }
                                groupedShape.path = VectorPath(elements: transformedElements)
                                groupedShape.updateBounds()
                                transformedGroupedShapes.append(groupedShape)
                            }
                            shape.groupedShapes = transformedGroupedShapes
                            shape.updateBounds()
                        } else if shape.typography != nil {
                            let currentPosition = shape.textPosition ?? CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                            let newPosition = transformPoint(currentPosition,
                                                            currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                            newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                            scaleX: scaleX, scaleY: scaleY)
                            shape.textPosition = newPosition
                            shape.transform = CGAffineTransform(translationX: newPosition.x, y: newPosition.y)
                            if scaleX != 1.0 || scaleY != 1.0 {
                                let newWidth = shape.bounds.width * scaleX
                                let newHeight = shape.bounds.height * scaleY
                                shape.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
                                if let areaSize = shape.areaSize {
                                    shape.areaSize = CGSize(width: areaSize.width * scaleX, height: areaSize.height * scaleY)
                                }
                            }
                        } else {
                            var transformedElements: [PathElement] = []
                            for element in shape.path.elements {
                                switch element {
                                case .move(let to):
                                    let pt = to.cgPoint
                                    let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.move(to: VectorPoint(newPt)))
                                case .line(let to):
                                    let pt = to.cgPoint
                                    let newPt = transformPoint(pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.line(to: VectorPoint(newPt)))
                                case .curve(let to, let control1, let control2):
                                    let toPt = to.cgPoint
                                    let c1Pt = control1.cgPoint
                                    let c2Pt = control2.cgPoint
                                    let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    let newC1 = transformPoint(c1Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    let newC2 = transformPoint(c2Pt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.curve(to: VectorPoint(newTo),
                                                                     control1: VectorPoint(newC1),
                                                                     control2: VectorPoint(newC2)))
                                case .quadCurve(let to, let control):
                                    let toPt = to.cgPoint
                                    let cPt = control.cgPoint
                                    let newTo = transformPoint(toPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                              newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                              scaleX: scaleX, scaleY: scaleY)
                                    let newC = transformPoint(cPt, currentOrigin: CGPoint(x: currentOriginX, y: currentOriginY),
                                                            newOrigin: CGPoint(x: newOriginX, y: newOriginY),
                                                            scaleX: scaleX, scaleY: scaleY)
                                    transformedElements.append(.quadCurve(to: VectorPoint(newTo),
                                                                         control: VectorPoint(newC)))
                                case .close:
                                    transformedElements.append(.close)
                                }
                            }
                            shape.path = VectorPath(elements: transformedElements)
                            shape.updateBounds()
                        }
                        for layerIndex in document.snapshot.layers.indices {
                            let shapes = document.getShapesForLayer(layerIndex)
                            if let shapeIndex = shapes.firstIndex(where: { $0.id == objectID }) {
                                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
                                if shape.typography != nil {
                                    if let position = shape.textPosition {
                                        document.updateTextPositionInUnified(id: shape.id, position: position)
                                    }
                                    if let areaSize = shape.areaSize {
                                        document.updateTextAreaSizeInUnified(id: shape.id, areaSize: areaSize)
                                    }
                                    document.updateTextBoundsInUnified(id: shape.id, bounds: shape.bounds)
                                }
                                document.triggerLayerUpdate(for: layerIndex)
                                break
                            }
                        }
                    }
                }
            }
        )
        updateValuesFromSelection()
    }

    private func applyScale() {
        guard let scaleX = Double(scaleXValue),
              let scaleY = Double(scaleYValue),
              scaleX > 0, scaleY > 0,
              let currentBounds = getSelectionBounds() else { return }
        let scaleFactorX = scaleX / 100.0
        let scaleFactorY = scaleY / 100.0
        guard abs(scaleFactorX - 1.0) > 0.001 || abs(scaleFactorY - 1.0) > 0.001 else { return }
        let originOffset = document.viewState.transformOrigin.point
        let originX = currentBounds.minX + currentBounds.width * originOffset.x
        let originY = currentBounds.minY + currentBounds.height * originOffset.y
        document.modifySelectedShapesWithUndo(
            preCapture: {
                for objectID in document.viewState.selectedObjectIDs {
                    if let vectorObject = document.snapshot.objects[objectID] {
                        var shape = vectorObject.shape
                        if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                            let scaleTransform = CGAffineTransform(translationX: originX, y: originY)
                                .scaledBy(x: scaleFactorX, y: scaleFactorY)
                                .translatedBy(x: -originX, y: -originY)
                            document.applyTransformToGroup(groupID: shape.id, transform: scaleTransform)
                        } else if shape.isGroupContainer {
                            for i in shape.groupedShapes.indices {
                                var groupedShape = shape.groupedShapes[i]
                                scaleShapePath(&groupedShape, scaleX: scaleFactorX, scaleY: scaleFactorY, originX: originX, originY: originY)
                                shape.groupedShapes[i] = groupedShape
                            }
                            shape.updateBounds()
                            document.updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        } else if shape.typography != nil {
                            if let pos = shape.textPosition {
                                let newX = originX + (pos.x - originX) * scaleFactorX
                                let newY = originY + (pos.y - originY) * scaleFactorY
                                shape.textPosition = CGPoint(x: newX, y: newY)
                                shape.transform = CGAffineTransform(translationX: newX, y: newY)
                                shape.bounds = CGRect(x: 0, y: 0,
                                                     width: shape.bounds.width * scaleFactorX,
                                                     height: shape.bounds.height * scaleFactorY)
                                if let areaSize = shape.areaSize {
                                    shape.areaSize = CGSize(width: areaSize.width * scaleFactorX,
                                                           height: areaSize.height * scaleFactorY)
                                }
                            }
                            document.updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        } else {
                            scaleShapePath(&shape, scaleX: scaleFactorX, scaleY: scaleFactorY, originX: originX, originY: originY)
                            document.updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        }
                    }
                }
            }
        )
        scaleXValue = "100"
        scaleYValue = "100"
        updateValuesFromSelection()
    }

    private func scaleShapePath(_ shape: inout VectorShape, scaleX: CGFloat, scaleY: CGFloat, originX: CGFloat, originY: CGFloat) {
        var scaledElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let newX = originX + (to.x - originX) * scaleX
                let newY = originY + (to.y - originY) * scaleY
                scaledElements.append(.move(to: VectorPoint(CGPoint(x: newX, y: newY))))
            case .line(let to):
                let newX = originX + (to.x - originX) * scaleX
                let newY = originY + (to.y - originY) * scaleY
                scaledElements.append(.line(to: VectorPoint(CGPoint(x: newX, y: newY))))
            case .curve(let to, let control1, let control2):
                let newToX = originX + (to.x - originX) * scaleX
                let newToY = originY + (to.y - originY) * scaleY
                let newC1X = originX + (control1.x - originX) * scaleX
                let newC1Y = originY + (control1.y - originY) * scaleY
                let newC2X = originX + (control2.x - originX) * scaleX
                let newC2Y = originY + (control2.y - originY) * scaleY
                scaledElements.append(.curve(
                    to: VectorPoint(CGPoint(x: newToX, y: newToY)),
                    control1: VectorPoint(CGPoint(x: newC1X, y: newC1Y)),
                    control2: VectorPoint(CGPoint(x: newC2X, y: newC2Y))
                ))
            case .quadCurve(let to, let control):
                let newToX = originX + (to.x - originX) * scaleX
                let newToY = originY + (to.y - originY) * scaleY
                let newCX = originX + (control.x - originX) * scaleX
                let newCY = originY + (control.y - originY) * scaleY
                scaledElements.append(.quadCurve(
                    to: VectorPoint(CGPoint(x: newToX, y: newToY)),
                    control: VectorPoint(CGPoint(x: newCX, y: newCY))
                ))
            case .close:
                scaledElements.append(.close)
            }
        }
        shape.path = VectorPath(elements: scaledElements)
        shape.updateBounds()
    }

    private func applyRotation() {
        guard let angle = Double(rotationValue),
              let currentBounds = getSelectionBounds() else { return }
        guard abs(angle) > 0.001 else { return }
        let radians = angle * .pi / 180.0
        let originOffset = document.viewState.transformOrigin.point
        let originX = currentBounds.minX + currentBounds.width * originOffset.x
        let originY = currentBounds.minY + currentBounds.height * originOffset.y
        document.modifySelectedShapesWithUndo(
            preCapture: {
                for objectID in document.viewState.selectedObjectIDs {
                    if let vectorObject = document.snapshot.objects[objectID] {
                        var shape = vectorObject.shape
                        if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                            let rotationTransform = CGAffineTransform(translationX: originX, y: originY)
                                .rotated(by: radians)
                                .translatedBy(x: -originX, y: -originY)
                            document.applyTransformToGroup(groupID: shape.id, transform: rotationTransform)
                        } else if shape.isGroupContainer {
                            for i in shape.groupedShapes.indices {
                                var groupedShape = shape.groupedShapes[i]
                                rotateShapePath(&groupedShape, radians: radians, originX: originX, originY: originY)
                                shape.groupedShapes[i] = groupedShape
                            }
                            shape.updateBounds()
                            document.updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        } else if shape.typography != nil {
                            if let pos = shape.textPosition {
                                let dx = pos.x - originX
                                let dy = pos.y - originY
                                let newX = originX + dx * cos(radians) - dy * sin(radians)
                                let newY = originY + dx * sin(radians) + dy * cos(radians)
                                shape.textPosition = CGPoint(x: newX, y: newY)
                                shape.transform = CGAffineTransform(translationX: newX, y: newY)
                            }
                            document.updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        } else {
                            rotateShapePath(&shape, radians: radians, originX: originX, originY: originY)
                            document.updateShapeByID(objectID, silent: false) { s in
                                s = shape
                            }
                        }
                    }
                }
            }
        )
        rotationValue = "0"
        updateValuesFromSelection()
    }

    private func rotateShapePath(_ shape: inout VectorShape, radians: CGFloat, originX: CGFloat, originY: CGFloat) {
        var rotatedElements: [PathElement] = []
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let rotated = rotatePoint(x: to.x, y: to.y, originX: originX, originY: originY, radians: radians)
                rotatedElements.append(.move(to: VectorPoint(rotated)))
            case .line(let to):
                let rotated = rotatePoint(x: to.x, y: to.y, originX: originX, originY: originY, radians: radians)
                rotatedElements.append(.line(to: VectorPoint(rotated)))
            case .curve(let to, let control1, let control2):
                let rotatedTo = rotatePoint(x: to.x, y: to.y, originX: originX, originY: originY, radians: radians)
                let rotatedC1 = rotatePoint(x: control1.x, y: control1.y, originX: originX, originY: originY, radians: radians)
                let rotatedC2 = rotatePoint(x: control2.x, y: control2.y, originX: originX, originY: originY, radians: radians)
                rotatedElements.append(.curve(
                    to: VectorPoint(rotatedTo),
                    control1: VectorPoint(rotatedC1),
                    control2: VectorPoint(rotatedC2)
                ))
            case .quadCurve(let to, let control):
                let rotatedTo = rotatePoint(x: to.x, y: to.y, originX: originX, originY: originY, radians: radians)
                let rotatedC = rotatePoint(x: control.x, y: control.y, originX: originX, originY: originY, radians: radians)
                rotatedElements.append(.quadCurve(
                    to: VectorPoint(rotatedTo),
                    control: VectorPoint(rotatedC)
                ))
            case .close:
                rotatedElements.append(.close)
            }
        }
        shape.path = VectorPath(elements: rotatedElements)
        shape.updateBounds()
    }

    private func rotatePoint(x: CGFloat, y: CGFloat, originX: CGFloat, originY: CGFloat, radians: CGFloat) -> CGPoint {
        let dx = x - originX
        let dy = y - originY
        let newX = originX + dx * cos(radians) - dy * sin(radians)
        let newY = originY + dx * sin(radians) + dy * cos(radians)
        return CGPoint(x: newX, y: newY)
    }
}

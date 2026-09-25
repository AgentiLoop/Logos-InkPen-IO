import SwiftUI

struct GuidesView: View {

    @ObservedObject var document: VectorDocument

    let showGuides: Bool
    let zoomLevel: Double
    let canvasOffset: CGPoint

    @Binding var liveDragOffset: CGPoint
    var body: some View {
        if showGuides {
            let _ = document.viewState.objectPositionUpdateTrigger
            let guideShapes = document.getGuideShapes()
            let selectedIDs = document.viewState.selectedObjectIDs
            let isKeylineMode = document.viewState.viewMode == .keyline
            GeometryReader { geometry in
                ZStack {
                    ForEach(guideShapes, id: \.id) { shape in
                        if shape.isGuide && shape.isVisible, let orientation = shape.guideOrientation {
                            GuideLineView(
                                shape: shape,
                                orientation: orientation,
                                isSelected: selectedIDs.contains(shape.id),
                                isKeylineMode: isKeylineMode,
                                dragOffset: liveDragOffset,
                                zoomLevel: zoomLevel,
                                canvasOffset: canvasOffset,
                                viewSize: geometry.size
                            )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct GuideLineView: View {
    let shape: VectorShape
    let orientation: Guide.Orientation
    let isSelected: Bool
    let isKeylineMode: Bool
    let dragOffset: CGPoint
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let viewSize: CGSize

    private var guideColor: Color {
        if isKeylineMode {
            return .black
        }
        return isSelected ? Color.nonPhotoBlueSelected : Color.nonPhotoBlue
    }

    var body: some View {
        Path { p in
            var position = extractGuidePosition()
            if isSelected {
                switch orientation {
                case .horizontal:
                    position += dragOffset.y
                case .vertical:
                    position += dragOffset.x
                }
            }
            switch orientation {
            case .horizontal:
                let screenY = position * zoomLevel + canvasOffset.y
                p.move(to: CGPoint(x: 0, y: screenY))
                p.addLine(to: CGPoint(x: viewSize.width, y: screenY))
            case .vertical:
                let screenX = position * zoomLevel + canvasOffset.x
                p.move(to: CGPoint(x: screenX, y: 0))
                p.addLine(to: CGPoint(x: screenX, y: viewSize.height))
            }
        }
        .stroke(guideColor, lineWidth: 1)
    }

    private func extractGuidePosition() -> CGFloat {
        guard let firstElement = shape.path.elements.first else { return 0 }
        switch firstElement {
        case .move(let point):
            switch orientation {
            case .horizontal:
                return CGFloat(point.y)
            case .vertical:
                return CGFloat(point.x)
            }
        default:
            return 0
        }
    }
}

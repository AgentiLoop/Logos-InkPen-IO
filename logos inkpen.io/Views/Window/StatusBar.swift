import SwiftUI

struct StatusBar: View {
    let zoomLevel: Double

    @ObservedObject var document: VectorDocument
    var body: some View {
        HStack {
            HStack(spacing: 2) {
                Text("Tool: \(document.viewState.currentTool.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if document.viewState.currentTool == .bezierPen {
                    Text("• Click to place points • Click near first point to close")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if document.viewState.currentTool == .directSelection {
                    Text("• Select anchor points and handles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if document.viewState.currentTool == .warp {
                    Text("• Select objects to warp • Drag handles to distort")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            HStack {
                if document.viewState.selectedObjectIDs.isEmpty {
                    Text("No selection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    let totalSelected = document.viewState.selectedObjectIDs.count
                    if let bounds = getSelectionBounds() {
                        Text("\(totalSelected) selected  •  W: \(formatPreciseDimension(bounds.width))pt H: \(formatPreciseDimension(bounds.height))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(totalSelected) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Text("Size: \(formatDimension(document.settings.width))×\(formatDimension(document.settings.height)) \(document.settings.unit.abbreviation)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(formatNumber(getTotalObjectCount())) obj  •  \(formatNumber(getTotalPointCount())) pts")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("Zoom: \(Int(zoomLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color.platformControlBackground)
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .top
        )
    }

    private func formatDimension(_ value: Double) -> String {
        let formatted = String(format: "%.5f", value)
        if formatted.contains(".") {
            var trimmed = formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            if trimmed.hasSuffix(".") {
                trimmed = String(trimmed.dropLast())
            }
            return trimmed
        }
        return formatted
    }

    private func formatPreciseDimension(_ value: CGFloat) -> String {
        let formatted = String(format: "%.5f", value)
        if formatted.contains(".") {
            var trimmed = formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            if trimmed.hasSuffix(".") {
                trimmed = String(trimmed.dropLast())
            }
            return trimmed
        }
        return formatted
    }

    private func getSelectionBounds() -> CGRect? {
        var combinedBounds: CGRect?
        for vectorObject in document.snapshot.objects.values {
            switch vectorObject.objectType {
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                if document.viewState.selectedObjectIDs.contains(shape.id) {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    if combinedBounds == nil {
                        combinedBounds = shapeBounds
                    } else {
                        combinedBounds = combinedBounds?.union(shapeBounds)
                    }
                }
            case .text:
                continue
            }
        }
        for vectorObject in document.snapshot.objects.values {
            if case .text(let shape) = vectorObject.objectType,
               document.viewState.selectedObjectIDs.contains(shape.id),

               let textObj = VectorText.from(shape) {
                let textBounds = CGRect(
                    x: textObj.position.x + textObj.bounds.minX,
                    y: textObj.position.y + textObj.bounds.minY,
                    width: textObj.bounds.width,
                    height: textObj.bounds.height
                ).applying(textObj.transform)
                if combinedBounds == nil {
                    combinedBounds = textBounds
                } else {
                    combinedBounds = combinedBounds?.union(textBounds)
                }
            }
        }
        return combinedBounds
    }

    private func getTotalObjectCount() -> Int {
        return document.snapshot.objects.count
    }

    private func getTotalPointCount() -> Int {
        var totalPoints = 0
        for vectorObject in document.snapshot.objects.values {
            switch vectorObject.objectType {
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                totalPoints += countPointsInPath(shape.path)
            case .text:
                break
            }
        }
        return totalPoints
    }

    private func countPointsInPath(_ path: VectorPath) -> Int {
        var count = 0
        for element in path.elements {
            switch element {
            case .move, .line, .quadCurve, .curve:
                count += 1
            case .close:
                break
            }
        }
        return count
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

import SwiftUI
import AppKit

struct ProfessionalOffsetPathSection: View {
    let selectedObjectIDs: Set<UUID>
    let document: VectorDocument

    @State private var offsetDistance: Double = 0.5
    @State private var selectedJoinType: JoinType = .round
    @State private var miterLimit: Double = 4.0
    @State private var showAdvanced: Bool = true
    @State private var keepOriginalPath: Bool = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Offset Path")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                Spacer()
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            if showAdvanced {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Offset:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f %@", offsetDistance, document.settings.unit.abbreviation))
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .monospacedDigit()
                        }
                        ZStack {

                            let maxOffset: Double = {
                                switch document.settings.unit {
                                case .inches: return 1.0
                                case .centimeters: return 10.0
                                case .millimeters: return 10.0
                                case .points: return 25.0
                                case .pixels: return 50.0
                                case .picas: return 12.0
                                }
                            }()
                            Slider(value: $offsetDistance, in: -maxOffset...maxOffset, step: 0.1)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            Capsule()
                                .fill(
                                    SwiftUI.LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue,
                                            Color.clear,
                                            Color.red
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 6)
                                .allowsHitTesting(false)
                        }
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep Original Path")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("Preserve original when creating offset")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $keepOriginalPath)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .controlSize(.small)
                    }
                    .help("Keep the original path when creating offset (Professional default)")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Joins:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            ForEach([JoinType.round, .square, .bevel, .miter], id: \.self) { joinType in
                                Button {
                                    selectedJoinType = joinType
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: joinType.iconName)
                                            .font(.system(size: 12))
                                        Text(joinType.displayName)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(selectedJoinType == joinType ? .accentColor : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedJoinType == joinType ? Color.accentColor.opacity(0.1) : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(selectedJoinType == joinType ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                            )
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .help(joinType.description)
                            }
                        }
                    }
                    if selectedJoinType == .miter {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Miter Limit:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(miterLimit, specifier: "%.1f")")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                    .monospacedDigit()
                            }
                            ZStack {
                                Capsule()
                                    .fill(Color.white)
                                    .frame(height: 6)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                                    )
                                Slider(value: $miterLimit, in: 1.0...20.0) {
                                    Text("Miter Limit")
                                }
                                .controlSize(.regular)
                                .tint(Color.clear)
                                Capsule()
                                    .fill(Color.blue)
                                    .frame(height: 6)
                                    .allowsHitTesting(false)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    Button {
                        performOffsetPath()
                    } label: {
                        Text("Offset Path")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .onTapGesture {
                        performOffsetPath()
                    }
                    .help("Create offset path with current settings (⌘⌥O)")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: document.settings.unit) { _, newUnit in

            let maxOffset: Double = {
                switch newUnit {
                case .inches: return 1.0
                case .centimeters: return 10.0
                case .millimeters: return 10.0
                case .points: return 25.0
                case .pixels: return 50.0
                case .picas: return 12.0
                }
            }()
            offsetDistance = min(max(offsetDistance, -maxOffset), maxOffset)
        }
    }

    private func canPerformOffset() -> Bool {
        return !selectedObjectIDs.isEmpty
    }

    private func performOffsetPath() {
        guard !selectedObjectIDs.isEmpty else { return }
        guard let layerIndex = document.selectedLayerIndex else { return }
        let selectedShapes = document.getSelectedShapes()

        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var removedObjectIDs: [UUID] = []
        for shape in selectedShapes {
            oldShapes[shape.id] = shape
            if !keepOriginalPath {
                removedObjectIDs.append(shape.id)
            }
        }
        let unit = document.settings.unit
        for shape in selectedShapes {
            let offsetInPoints = CGFloat(unit.toPoints(offsetDistance))
            let offsetPath = shape.path.cgPath.copy(strokingWithWidth: abs(offsetInPoints) * 2.0,
                                                    lineCap: .round,
                                                    lineJoin: mapJoinTypeToCoreGraphics(selectedJoinType),
                                                    miterLimit: CGFloat(miterLimit))
            var finalPath: CGPath
            if offsetDistance >= 0 {
                if let unionResult = CoreGraphicsPathOperations.union(shape.path.cgPath, offsetPath, using: .winding) {
                    finalPath = unionResult
                } else {
                    finalPath = offsetPath
                }
            } else {
                if let subtractResult = CoreGraphicsPathOperations.subtract(offsetPath, from: shape.path.cgPath, using: .winding) {
                    finalPath = subtractResult
                } else {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Invalid Offset Value"
                        alert.informativeText = "The negative offset value \(String(format: "%.1f", offsetDistance))\(unit.abbreviation) is too large for \"\(shape.name)\". The shape would be completely consumed."
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                    continue
                }
            }
            let offsetVectorPath = VectorPath(cgPath: finalPath)
            let offsetSign = offsetDistance > 0 ? "+" : ""
            let offsetShape = VectorShape(
                name: "\(shape.name) Offset \(offsetSign)\(String(format: "%.1f", offsetDistance))\(unit.abbreviation)",
                path: offsetVectorPath,
                strokeStyle: shape.strokeStyle,
                fillStyle: shape.fillStyle,
                transform: shape.transform,
                opacity: shape.opacity
            )
            newShapes[offsetShape.id] = offsetShape
        }
        let placeBehind = offsetDistance > 0 && keepOriginalPath
        let command = GroupCommand(
            operation: .pathOperation,
            layerIndex: layerIndex,
            removedObjectIDs: removedObjectIDs,
            removedShapes: keepOriginalPath ? [:] : oldShapes,
            addedObjectIDs: Array(newShapes.keys),
            addedShapes: newShapes,
            oldSelectedObjectIDs: Set(oldShapes.keys),
            newSelectedObjectIDs: Set(newShapes.keys),
            behindObjectIDs: placeBehind ? Set(oldShapes.keys) : []
        )
        document.executeCommand(command)
        document.viewState.selectedObjectIDs = Set(newShapes.keys)
        document.viewState.orderedSelectedObjectIDs = Array(newShapes.keys)
    }

    private func mapJoinTypeToCoreGraphics(_ joinType: JoinType) -> CGLineJoin {
        switch joinType {
        case .round: return .round
        case .miter: return .miter
        case .bevel: return .bevel
        case .square: return .miter
        }
    }

    private func findOutsidePath(from trimmedPaths: [CGPath], original: CGPath, offset: CGPath) -> CGPath? {
        guard !trimmedPaths.isEmpty else { return nil }
        let offsetBounds = offset.boundingBoxOfPath

        var bestPath: CGPath?
        var bestScore: CGFloat = 0
        for path in trimmedPaths {
            let pathBounds = path.boundingBoxOfPath
            let pathArea = pathBounds.width * pathBounds.height
            let areaScore = pathArea
            let proximityScore = pathBounds.intersection(offsetBounds).width * pathBounds.intersection(offsetBounds).height
            let totalScore = areaScore + proximityScore * 2.0
            if totalScore > bestScore {
                bestScore = totalScore
                bestPath = path
            }
        }
        return bestPath ?? trimmedPaths.first
    }
}

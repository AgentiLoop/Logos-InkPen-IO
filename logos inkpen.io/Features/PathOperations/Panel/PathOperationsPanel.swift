import SwiftUI

struct PathOperationsPanel: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    let document: VectorDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Path Operations")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button {
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Professional Path Operations")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                Text("Shape Modes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach([PathfinderOperation.union, .minusFront, .intersect, .exclude], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Path Operations Effects")
                        .font(.caption)
                    .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                                            ForEach([PathfinderOperation.mosaic, .cut, .merge, .separate, .crop, .dieline, .kick, .combine], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            ProfessionalOffsetPathSection(
                selectedObjectIDs: selectedObjectIDs,
                document: document
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("Path Cleanup")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                VStack(spacing: 8) {
                    Button {
                        mergeCoincidentPointsInSelectedShapes()
                    } label: {
                        Text("Merge Points")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        mergeCoincidentPointsInSelectedShapes()
                    }
                    .help("Merge coincident points in selected shapes (excluding start and end points)")
                    Button {
                        removeOverlapFromSelectedShapes()
                    } label: {
                        Text("Remove Overlap")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        removeOverlapFromSelectedShapes()
                    }
                    .help("Remove self-intersections and overlapping areas within selected shapes")
                    Button {
                        removeOverlapFromAllShapes()
                    } label: {
                        Text("Remove All Overlaps")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        removeOverlapFromAllShapes()
                    }
                    .help("Remove overlaps from all shapes in the document")
                }
                .padding(.horizontal, 16)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Clipping Masks")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow Content Selection")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("Enable selection inside clipping masks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { AppState.shared.enableClippingMaskContentSelection },
                        set: { AppState.shared.enableClippingMaskContentSelection = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                VStack(spacing: 8) {
                    Button {
                        document.makeClippingMaskFromSelection()
                    } label: {
                        Text("Make Clipping Mask")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        document.makeClippingMaskFromSelection()
                    }
                    Button {
                        document.releaseClippingMaskForSelection()
                    } label: {
                        Text("Release Clipping Mask")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .onTapGesture {
                        document.releaseClippingMaskForSelection()
                    }
                }
                .padding(.horizontal, 16)
            }
            Spacer()
                }
            }
        }
    }

    private func canPerformOperation(_ operation: PathfinderOperation) -> Bool {
        let selectedShapes = document.getSelectedShapes()
        let paths = selectedShapes.map { $0.path.cgPath }
        return ProfessionalPathOperations.canPerformOperation(operation, on: paths)
    }

    private func performPathfinderOperation(_ operation: PathfinderOperation) {
        _ = document.performPathfinderOperation(operation)
    }

    private func removeOverlapFromSelectedShapes() {
        guard !document.viewState.selectedObjectIDs.isEmpty else { return }
        let selectedShapes = document.getSelectedShapes()

        var processedCount = 0
        for shape in selectedShapes {
            if removeOverlapFromShape(shape) {
                processedCount += 1
            }
        }
    }

    private func removeOverlapFromAllShapes() {
        let allShapes = document.snapshot.objects.values.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType {
                return shape
            }
            return nil
        }
        guard !allShapes.isEmpty else { return }
        var processedCount = 0
        for shape in allShapes {
            if removeOverlapFromShape(shape) {
                processedCount += 1
            }
        }
    }

    @discardableResult
    private func removeOverlapFromShape(_ shape: VectorShape) -> Bool {
        let originalPath = shape.path.cgPath
        guard !originalPath.isEmpty && !originalPath.boundingBox.isNull && !originalPath.boundingBox.isInfinite else {
            return false
        }
        if let cleanedPath = CoreGraphicsPathOperations.union(originalPath, originalPath) {
            guard !cleanedPath.isEmpty && !cleanedPath.boundingBox.isNull && !cleanedPath.boundingBox.isInfinite else {
                return false
            }
            if let layerIndex = document.snapshot.layers.firstIndex(where: { layer in
                document.getShapesForLayer(document.snapshot.layers.firstIndex(of: layer) ?? -1).contains { $0.id == shape.id }
            }),
               document.getShapesForLayer(layerIndex).contains(where: { $0.id == shape.id }) {
                document.updateShapePathUnified(id: shape.id, path: VectorPath(cgPath: cleanedPath))
                return true
            }
        }
        Log.error("❌ REMOVE OVERLAP: Failed to clean shape: \(shape.name)", category: .error)
        return false
    }

    private func mergeCoincidentPointsInSelectedShapes() {
        guard !document.viewState.selectedObjectIDs.isEmpty else {
            Log.info("No shapes selected", category: .general)
            return
        }
        let selectedShapes = document.getSelectedShapes()
        let tolerance: Double = 1.0
        Log.info("Merging ALL coincident points in \(selectedShapes.count) shapes (tolerance: \(tolerance))", category: .general)
        for shape in selectedShapes {
            let originalCount = shape.path.elements.count
            let cleanedPath = ProfessionalPathOperations.mergeAdjacentCoincidentPoints(in: shape.path, tolerance: tolerance)
            let newCount = cleanedPath.elements.count
            Log.info("Shape '\(shape.name)': \(originalCount) -> \(newCount) elements (removed \(originalCount - newCount))", category: .general)
            if newCount != originalCount {
                document.updateShapePathUnified(id: shape.id, path: cleanedPath)
            }
        }
    }
}

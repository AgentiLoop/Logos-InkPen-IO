import SwiftUI
import Combine
import AppKit

struct ProfessionalLayerRow: View {
    let layerIndex: Int
    let layer: Layer

    @ObservedObject var document: VectorDocument

    @Binding var selectedLayerIndex: Int?

    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @State private var isExpanded: Bool
    @State private var previewOpacity: Double? = nil
    @State private var selectionAnchorID: UUID? = nil
    @State private var selectionRangeMin: Int? = nil
    @State private var selectionRangeMax: Int? = nil
    @State private var cachedObjectIDs: [UUID] = []
    private var isSelected: Bool {
        document.settings.selectedLayerId == layer.id
    }

    private var layerObjects: [VectorObject] {
        cachedObjectIDs.compactMap { document.snapshot.objects[$0] }
    }
    private var layerInBounds: Bool { layerIndex >= 0 && layerIndex < document.snapshot.layers.count }

    private var isVisibleBinding: Binding<Bool> {
        Binding(
            get: { guard layerInBounds else { return true }; return document.snapshot.layers[layerIndex].isVisible },
            set: { newValue in
                guard layerInBounds else { return }
                if document.snapshot.layers[layerIndex].isVisible != newValue {
                    document.snapshot.layers[layerIndex].isVisible = newValue
                    document.changeNotifier.notifyLayersChanged()
                }
            }
        )
    }

    private var isLockedBinding: Binding<Bool> {
        Binding(
            get: { guard layerInBounds else { return false }; return document.snapshot.layers[layerIndex].isLocked },
            set: { newValue in
                guard layerInBounds else { return }
                if document.snapshot.layers[layerIndex].isLocked != newValue {
                    document.snapshot.layers[layerIndex].isLocked = newValue
                    document.changeNotifier.notifyLayersChanged()
                }
            }
        )
    }

    init(layerIndex: Int, layer: Layer, document: VectorDocument, selectedLayerIndex: Binding<Int?>) {
        self.layerIndex = layerIndex
        self.layer = layer
        self.document = document
        self._selectedLayerIndex = selectedLayerIndex
        if layerIndex <= 1 {
            _isExpanded = State(initialValue: document.settings.layerExpansionState[layer.id] ?? false)
        } else {
            _isExpanded = State(initialValue: document.settings.layerExpansionState[layer.id] ?? true)
        }
        _cachedObjectIDs = State(initialValue: Array(layer.objectIDs.reversed()))
    }

    private func updateCachedObjects() {
        cachedObjectIDs = Array(layer.objectIDs.reversed())
    }

    private func setExpanded(_ value: Bool) {
        isExpanded = value
        var updatedSettings = document.settings
        updatedSettings.layerExpansionState[layer.id] = value
        document.settings = updatedSettings
    }

    private var layerColor: Binding<Color> {
        Binding(
            get: {
                guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return .blue }
                let colorName = document.snapshot.layers[layerIndex].color.name
                return Color.layerColorPalette.first { $0.name == colorName }?.color ?? .blue
            },
            set: { newColor in
                guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }
                if let match = Color.layerColorPalette.first(where: { $0.color.description == newColor.description }) {
                    document.snapshot.layers[layerIndex].color = LayerColor(name: match.name)
                    document.changeNotifier.notifyLayersChanged()
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 21, height: 1)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 19, height: 1)
                    Spacer()
                }
                .padding(.leading, 2.5)
                .padding(.trailing, 4)
                HStack(spacing: 2) {
                    Button(action: {
                        isVisibleBinding.wrappedValue.toggle()
                    }) {
                        Image(systemName: isVisibleBinding.wrappedValue ? "eye" : "eye.slash")
                            .font(.system(size: 11))
                            .foregroundColor(isVisibleBinding.wrappedValue ? .primary : .secondary.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(isVisibleBinding.wrappedValue ? "Hide Layer" : "Show Layer")
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                if !document.viewState.isDraggingVisibility {
                                    document.viewState.isDraggingVisibility = true
                                    document.processedLayersDuringDrag.removeAll()
                                    document.snapshot.layers[layerIndex].isVisible.toggle()
                                    document.processedLayersDuringDrag.insert(layerIndex)
                                    document.changeNotifier.notifyLayersChanged()
                                }
                            }
                            .onEnded { _ in
                                document.viewState.isDraggingVisibility = false
                                document.processedLayersDuringDrag.removeAll()
                            }
                    )
                    Button(action: {
                        isLockedBinding.wrappedValue.toggle()
                    }) {
                        Image(systemName: isLockedBinding.wrappedValue ? "lock.fill" : "lock.open")
                            .font(.system(size: 10))
                            .foregroundColor(isLockedBinding.wrappedValue ? .orange : .secondary.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(isLockedBinding.wrappedValue ? "Unlock Layer" : "Lock Layer")
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                if !document.viewState.isDraggingLock {
                                    document.viewState.isDraggingLock = true
                                    document.processedLayersDuringDrag.removeAll()
                                    document.snapshot.layers[layerIndex].isLocked.toggle()
                                    document.processedLayersDuringDrag.insert(layerIndex)
                                    document.changeNotifier.notifyLayersChanged()
                                }
                            }
                            .onEnded { _ in
                                document.viewState.isDraggingLock = false
                                document.processedLayersDuringDrag.removeAll()
                            }
                    )
                    HStack(spacing: 4) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                if NSEvent.modifierFlags.contains(.option) {
                                    var updatedSettings = document.settings

                                    let shouldExpand = !isExpanded
                                    for layer in document.snapshot.layers {
                                        updatedSettings.layerExpansionState[layer.id] = shouldExpand
                                    }
                                    document.settings = updatedSettings
                                } else {
                                    setExpanded(!isExpanded)
                                }
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(0))
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Click to expand/collapse layer. Option-click to expand/collapse all layers.")
                        ColorSwatchButton(
                            color: layerColor,
                            availableColors: Color.layerColorPalette
                        ) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(layerColor.wrappedValue)
                                .frame(width: 4, height: 16)
                        }
                        HStack(spacing: 0) {
                            if isEditingName {
                                TextField("Layer Name", text: $editedName, onCommit: {
                                    if !editedName.isEmpty {
                                        document.snapshot.layers[layerIndex].name = editedName
                                        document.changeNotifier.notifyLayersChanged()
                                    }
                                    isEditingName = false
                                })
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                                .onAppear {
                                    editedName = layer.name
                                }
                            } else {
                                Text(layer.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                    .onTapGesture(count: 2) {
                                        isEditingName = true
                                        editedName = layer.name
                                    }
                            }
                            Spacer()
                            let objectCount = layerIndex < document.snapshot.layers.count ? document.snapshot.layers[layerIndex].objectIDs.count : 0
                            Text("\(objectCount)")
                                .font(.system(size: 9))
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.trailing, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ?
                                  Color.accentColor.opacity(0.08) :
                                    Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelected ?
                                            Color.accentColor.opacity(0.2) :
                                                Color.clear, lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        document.settings.selectedLayerId = layer.id
                        document.settings.selectedLayerName = layer.name
                        document.viewState.selectedObjectIDs.removeAll()
                    }
                }
                .padding(.horizontal, 4)
            }
            if isExpanded {
                LazyVStack(spacing: 0) {
                    ForEach(Array(layerObjects.enumerated()), id: \.element.id) { index, newVectorObject in
                        let isLast = index == layerObjects.count - 1
                        objectRowForType(newVectorObject: newVectorObject, isLast: isLast)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.9), value: layerObjects.map { $0.id })
            }
        }
        .background(
            Group {
                if isSelected {
                    Color.clear.onReceive(NotificationCenter.default.publisher(for: Notification.Name("LayerOpacityUpdate"))) { notification in
                        guard let userInfo = notification.userInfo,
                              let layerID = userInfo["layerID"] as? UUID,
                              layerID == layer.id else {
                            return
                        }
                        if let opacity = userInfo["opacity"] as? Double {
                            document.snapshot.layers[layerIndex].opacity = opacity
                        }
                    }
                }
            }
        )
        .if(layer.name != "Canvas" && layer.name != "Pasteboard" && layer.name != "Guides") { view in
            view.draggable(DraggableItem.layer(
                DraggableLayer(
                    layerIndex: layerIndex,
                    layerId: layer.id
                )
            )) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(layerColor.wrappedValue)
                        .frame(width: 4, height: 16)
                    Text(layer.name)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
                .opacity(0.9)
            }
        }
        .onAppear {
            updateCachedObjects()
        }
        .onChange(of: document.viewState.layerUpdateTriggers[layer.id]) { _, _ in
            updateCachedObjects()
        }
        .onChange(of: layer.objectIDs) { _, _ in
            updateCachedObjects()
        }
        .dropDestination(for: DraggableItem.self) { items, location in
            guard let droppedItem = items.first else { return false }
            switch droppedItem {
            case .layer(let draggableLayer):
                let droppedLayerId = draggableLayer.layerId
                if droppedLayerId == layer.id {
                    return false
                }
                let targetLayerId: UUID
                if layerIndex <= 1 {
                    if document.snapshot.layers.count > 2 {
                        targetLayerId = document.snapshot.layers[2].id
                    } else {
                        return false
                    }
                } else {
                    targetLayerId = layer.id
                }
                document.reorderLayer(sourceLayerId: droppedLayerId, targetLayerId: targetLayerId)
                return true
            case .vectorObject(let vectorObj):
                let targetIndex = layerIndex <= 2 ? 3 : layerIndex
                if document.viewState.selectedObjectIDs.contains(vectorObj.objectId) && document.viewState.selectedObjectIDs.count > 1 {
                    document.moveObjectsToLayer(objectIds: Array(document.viewState.selectedObjectIDs), targetLayerIndex: targetIndex)
                } else {
                    document.moveObjectToLayer(objectId: vectorObj.objectId, targetLayerIndex: targetIndex)
                }
                return true
            }
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private func objectRowForType(newVectorObject: VectorObject, isLast: Bool) -> some View {
        switch newVectorObject.objectType {
        case .text(let shape):
            ObjectRow(
                objectType: .text,
                objectId: shape.id,
                name: {
                    guard let content = shape.textContent, !content.isEmpty else {
                        return "Text"
                    }
                    let firstLine = content
                        .split(whereSeparator: { $0.isNewline })
                        .first
                        .map(String.init) ?? content
                    let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
                    return trimmed.isEmpty ? "Text" : trimmed
                }(),
                isSelected: document.viewState.selectedObjectIDs.contains(newVectorObject.id),
                onSelect: { isShiftPressed, isCommandPressed in
                    handleObjectSelection(newVectorObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                },
                layerIndex: layerIndex,
                document: document,
                showBottomIndicator: isLast
            )
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
        case .group(let shape),
             .clipGroup(let shape):
            ObjectRow(
                objectType: .group,
                objectId: shape.id,
                name: shape.name,
                isSelected: document.viewState.selectedObjectIDs.contains(newVectorObject.id),
                onSelect: { isShiftPressed, isCommandPressed in
                    handleObjectSelection(newVectorObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                },
                layerIndex: layerIndex,
                document: document,
                memberIDs: shape.memberIDs.isEmpty ? shape.groupedShapes.map { $0.id } : shape.memberIDs,
                showBottomIndicator: isLast
            )
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
        case .shape(let shape),
             .image(let shape),
             .warp(let shape),
             .clipMask(let shape),
             .guide(let shape):
            ObjectRow(
                objectType: .shape,
                objectId: shape.id,
                name: shape.name,
                isSelected: document.viewState.selectedObjectIDs.contains(newVectorObject.id),
                onSelect: { isShiftPressed, isCommandPressed in
                    handleObjectSelection(newVectorObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                },
                layerIndex: layerIndex,
                document: document,
                showBottomIndicator: isLast
            )
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
        }
    }

    private func handleObjectSelection(_ objectID: UUID, layerIndex: Int, isShiftPressed: Bool, isCommandPressed: Bool) {
        guard document.snapshot.objects[objectID] != nil else {
            return
        }
        document.settings.selectedLayerId = layer.id
        document.settings.selectedLayerName = layer.name
        if isCommandPressed {
            if document.viewState.selectedObjectIDs.contains(objectID) {
                document.viewState.orderedSelectedObjectIDs.removeAll { $0 == objectID }
                document.viewState.selectedObjectIDs.remove(objectID)
            } else {
                document.viewState.orderedSelectedObjectIDs.append(objectID)
                document.viewState.selectedObjectIDs.insert(objectID)
            }
        } else if isShiftPressed {
            if let anchorID = selectionAnchorID {
                let objectIDs = layerIndex < document.snapshot.layers.count ? document.snapshot.layers[layerIndex].objectIDs : []
                let reversedIDs = Array(objectIDs.reversed())
                if let anchorIndex = reversedIDs.firstIndex(of: anchorID),

                   let clickedIndex = reversedIDs.firstIndex(of: objectID) {
                    let currentMin = selectionRangeMin ?? anchorIndex
                    let currentMax = selectionRangeMax ?? anchorIndex
                    let newMin = min(currentMin, clickedIndex)
                    let newMax = max(currentMax, clickedIndex)
                    selectionRangeMin = newMin
                    selectionRangeMax = newMax
                    let rangeIDs = Array(reversedIDs[newMin...newMax])
                    document.viewState.orderedSelectedObjectIDs = rangeIDs
                    document.viewState.selectedObjectIDs = Set(rangeIDs)
                } else {
                    if !document.viewState.selectedObjectIDs.contains(objectID) {
                        document.viewState.orderedSelectedObjectIDs.append(objectID)
                    }
                    document.viewState.selectedObjectIDs.insert(objectID)
                }
            } else {
                if !document.viewState.selectedObjectIDs.contains(objectID) {
                    document.viewState.orderedSelectedObjectIDs.append(objectID)
                }
                document.viewState.selectedObjectIDs.insert(objectID)
                selectionAnchorID = objectID
            }
        } else {
            document.viewState.orderedSelectedObjectIDs = [objectID]
            document.viewState.selectedObjectIDs = [objectID]
            selectionAnchorID = objectID
            selectionRangeMin = nil
            selectionRangeMax = nil
        }
        document.triggerLayerUpdate(for: layerIndex)
    }
}

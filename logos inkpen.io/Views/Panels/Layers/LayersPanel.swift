import SwiftUI

extension Color {
    static let layerColorPalette: [(name: String, color: Color)] = [
        (LayerColorName.maroon, Color(.displayP3, red: 0.75, green: 0.2, blue: 0.2)),
        (LayerColorName.red, Color.red),
        (LayerColorName.vermillion, Color(.displayP3, red: 0.8, green: 0.38, blue: 0.2)),
        (LayerColorName.rust, Color(.displayP3, red: 0.85, green: 0.5, blue: 0.15)),
        (LayerColorName.orange, Color.orange),
        (LayerColorName.amber, Color(.displayP3, red: 0.82, green: 0.62, blue: 0.2)),
        (LayerColorName.yellow, Color.yellow),
        (LayerColorName.chartreuse, Color(.displayP3, red: 0.55, green: 0.72, blue: 0.2)),
        (LayerColorName.lime, Color(.displayP3, red: 0.4, green: 0.68, blue: 0.28)),
        (LayerColorName.green, Color.green),
        (LayerColorName.emerald, Color(.displayP3, red: 0.2, green: 0.65, blue: 0.3)),
        (LayerColorName.spring, Color(.displayP3, red: 0.2, green: 0.68, blue: 0.5)),
        (LayerColorName.ocean, Color(.displayP3, red: 0.15, green: 0.65, blue: 0.72)),
        (LayerColorName.cyan, Color.cyan),
        (LayerColorName.sky, Color(.displayP3, red: 0.32, green: 0.58, blue: 0.82)),
        (LayerColorName.blue, Color.blue),
        (LayerColorName.azure, Color(.displayP3, red: 0.18, green: 0.4, blue: 0.78)),
        (LayerColorName.indigo, Color(.displayP3, red: 0.2, green: 0.25, blue: 0.75)),
        (LayerColorName.violet, Color(.displayP3, red: 0.4, green: 0.25, blue: 0.7)),
        (LayerColorName.orchid, Color(.displayP3, red: 0.55, green: 0.25, blue: 0.65)),
        (LayerColorName.purple, Color.purple),
        (LayerColorName.magenta, Color(.displayP3, red: 0.7, green: 0.2, blue: 0.5)),
        (LayerColorName.pink, Color.pink),
        (LayerColorName.rose, Color(.displayP3, red: 0.8, green: 0.3, blue: 0.4)),
        (LayerColorName.gray, Color.gray)
    ]
}
private let kLayerTextStyle: Font = .system(size: 11)
private let kLayerControlLabelWidth: CGFloat = 50
private let kLayerPercentageWidth: CGFloat = 35

extension View {

    @ViewBuilder
    func layerText(width: CGFloat? = nil, alignment: Alignment = .leading) -> some View {
        if let width = width {
            self
                .font(kLayerTextStyle)
                .foregroundColor(.secondary)
                .frame(width: width, alignment: alignment)
        } else {
            self
                .font(kLayerTextStyle)
                .foregroundColor(.secondary)
        }
    }
}

struct LayersPanel: View {

    @ObservedObject var document: VectorDocument

    @Binding var layerPreviewOpacities: [UUID: Double]
    @Binding var selectedLayerIndex: Int?
    @Binding var processedLayersDuringDrag: Set<Int>
    @Binding var processedObjectsDuringDrag: Set<UUID>

    @State private var layerOpacityState: Double = 1.0
    @State private var lastSentPercentage: Int = 100
    private var selectedIndex: Int? {
        if let selectedLayerId = document.settings.selectedLayerId {
            return document.snapshot.layers.firstIndex(where: { $0.id == selectedLayerId })
        }
        return document.snapshot.layers.count > 2 ? 2 : nil
    }

    private var overlaysEnabled: Bool {
        return !visibleRows.isEmpty
    }

    private enum RowType: Hashable {
        case layer(index: Int)
        case object(layerIndex: Int, objectId: UUID)
        case childObject(layerIndex: Int, parentObjectId: UUID, childShapeId: UUID)
    }

    private var visibleRows: [RowType] {
        var rows: [RowType] = []

        func addNestedGroupChildren(childShape: VectorShape, layerIndex: Int, parentObjectId: UUID) {
            guard childShape.isGroupContainer else { return }
            let isChildGroupExpanded = document.settings.groupExpansionState[childShape.id] ?? false
            guard isChildGroupExpanded else { return }
            let nestedMembers = document.resolveGroupMembers(childShape)

            let orderedNested: [VectorShape] = {
                if childShape.isClippingGroup { return nestedMembers }
                return Array(nestedMembers.reversed())
            }()
            for nestedChild in orderedNested {
                rows.append(.childObject(layerIndex: layerIndex, parentObjectId: childShape.id, childShapeId: nestedChild.id))
                addNestedGroupChildren(childShape: nestedChild, layerIndex: layerIndex, parentObjectId: nestedChild.id)
            }
        }
        for (layerIndex, layer) in document.snapshot.layers.enumerated().reversed() {
            rows.append(.layer(index: layerIndex))

            let isExpanded = if layerIndex <= 1 {
                document.settings.layerExpansionState[layer.id] ?? false
            } else {
                document.settings.layerExpansionState[layer.id] ?? true
            }
            if isExpanded {
                let objectIDs = document.snapshot.layers[layerIndex].objectIDs
                for objectID in objectIDs.reversed() {
                    if let object = document.snapshot.objects[objectID] {
                        rows.append(.object(layerIndex: layerIndex, objectId: object.id))
                        let isGroupExpanded = document.settings.groupExpansionState[object.id] ?? false
                        if isGroupExpanded {
                            switch object.objectType {
                            case .group(let shape), .clipGroup(let shape):
                                let memberShapes = document.resolveGroupMembers(shape)

                                let ordered: [VectorShape] = {
                                    if case .clipGroup = object.objectType { return memberShapes }
                                    return Array(memberShapes.reversed())
                                }()
                                for childShape in ordered {
                                    rows.append(.childObject(layerIndex: layerIndex, parentObjectId: object.id, childShapeId: childShape.id))
                                    addNestedGroupChildren(childShape: childShape, layerIndex: layerIndex, parentObjectId: childShape.id)
                                }
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            layersHeader
            Divider().padding(.horizontal, 6.5)
            if let index = selectedIndex {
                layerControlsSection(for: index)
                    .frame(maxWidth: .infinity)
                Divider().padding(.horizontal, 6.5)
            }
            layersScrollContent
            Spacer()
        }
        .onChange(of: selectedIndex) { _, newIndex in
            if let index = newIndex, index < document.snapshot.layers.count {
                layerOpacityState = document.snapshot.layers[index].opacity
            }
        }
        .onAppear {
            if let index = selectedIndex, index < document.snapshot.layers.count {
                layerOpacityState = document.snapshot.layers[index].opacity
            }
        }
    }

    private var layersHeader: some View {
        HStack {
            Text("Layer")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: {
                document.addLayer(name: "New Layer")
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Add New Layer")
            Button(action: {
                if let idx = selectedIndex {
                    document.removeLayer(at: idx)
                }
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(selectedIndex == nil || document.snapshot.layers.count <= 1)
            .help("Remove Selected Layer")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func layerControlsSection(for layerIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Opacity")
                    .layerText(width: kLayerControlLabelWidth)
                ZStack {
                    Capsule()
                        .fill(
                            SwiftUI.LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(white: 0.00),
                                    Color(white: 1.00)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 6)
                        .allowsHitTesting(false)
                    Slider(
                        value: $layerOpacityState,
                        in: 0...1,
                        onEditingChanged: { isEditing in
                            if !isEditing, layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                                document.snapshot.layers[layerIndex].opacity = layerOpacityState
                                layerPreviewOpacities.removeValue(forKey: document.snapshot.layers[layerIndex].id)
                                document.triggerLayerUpdate(for: layerIndex)
                            }
                        }
                    )
                    .onChange(of: layerOpacityState) { _, newValue in
                        if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                            let currentPercentage = Int(newValue * 100)
                            if currentPercentage != lastSentPercentage {
                                lastSentPercentage = currentPercentage
                                layerPreviewOpacities[document.snapshot.layers[layerIndex].id] = newValue
                            }
                        }
                    }
                    .controlSize(.regular)
                    .tint(Color.clear)
                }
                .frame(maxWidth: .infinity)
                Text("\(Int(layerOpacityState * 100))%")
                    .layerText(width: kLayerPercentageWidth, alignment: .trailing)
            }
            HStack(spacing: 8) {
                Text("Blend")
                    .layerText(width: kLayerControlLabelWidth)
                Picker("", selection: Binding(
                    get: {
                        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return BlendMode.normal }
                        return document.snapshot.layers[layerIndex].blendMode
                    },
                    set: { (newValue: BlendMode) in
                        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }
                        var updatedLayer = document.snapshot.layers[layerIndex]
                        updatedLayer.blendMode = newValue
                        document.snapshot.layers[layerIndex] = updatedLayer
                        document.triggerLayerUpdate(for: layerIndex)
                    }
                )) {
                    ForEach(BlendMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .frame(width: 100)
                .labelsHidden()
                .pickerStyle(.menu)
                Spacer(minLength: 10)
                    .frame(width: 10)
                ColorSwatchButton(
                    color: Binding(
                        get: {
                            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return .blue }
                            let colorName = document.snapshot.layers[layerIndex].color.name
                            return Color.layerColorPalette.first { $0.name == colorName }?.color ?? .blue
                        },
                        set: { newColor in
                            guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }
                            if let match = Color.layerColorPalette.first(where: { $0.color.description == newColor.description }) {
                                document.snapshot.layers[layerIndex].color = LayerColor(name: match.name)
                                document.triggerLayerUpdate(for: layerIndex)
                            }
                        }
                    ),
                    availableColors: Color.layerColorPalette
                )
                .offset(x:12)
                Text("Color")
                    .layerText(width: kLayerControlLabelWidth)
                    .multilineTextAlignment(.trailing)
                    .offset(x:20)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func dragOverlay(
        xPosition: CGFloat,
        isDragging: WritableKeyPath<DocumentViewState, Bool>,
        toggle: @escaping (RowType) -> Void
    ) -> some View {
        ZStack {
            ForEach(Array(visibleRows.enumerated()), id: \.offset) { rowIndex, rowType in
                let rowY = CGFloat(rowIndex) * kLayerRowHeight
                let iconCenterY = rowY + (kLayerRowHeight / 2)
                Color.red.opacity(0.0000000)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
                    .position(x: xPosition, y: iconCenterY)
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !document.viewState[keyPath: isDragging] {
                        document.viewState[keyPath: isDragging] = true
                        processedLayersDuringDrag.removeAll()
                        processedObjectsDuringDrag.removeAll()
                        let startY = value.startLocation.y
                        let rowIndex = Int(startY / kLayerRowHeight)
                        if rowIndex >= 0 && rowIndex < visibleRows.count {
                            toggle(visibleRows[rowIndex])
                        }
                    }
                    let currentY = value.location.y
                    let rowIndex = Int(currentY / kLayerRowHeight)
                    if rowIndex >= 0 && rowIndex < visibleRows.count {
                        toggle(visibleRows[rowIndex])
                    }
                }
                .onEnded { _ in
                    document.viewState[keyPath: isDragging] = false
                    processedLayersDuringDrag.removeAll()
                    processedObjectsDuringDrag.removeAll()
                }
        )
    }

    private var layersScrollContent: some View {
        return ScrollView(.vertical, showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(document.snapshot.layers.enumerated()).reversed(), id: \.element.id) { (layerIndex, layer) in
                        layerRowContent(for: layerIndex)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.9), value: document.changeNotifier.layerChangeToken)
                .padding(.horizontal, 4)
                if overlaysEnabled {
                    let iconSize: CGFloat = 20
                    let iconSpacing: CGFloat = 2
                    let rowPadding: CGFloat = 4
                    let eyeIconX = rowPadding + (iconSize / 2)
                    let lockIconX = rowPadding + iconSize + iconSpacing + (iconSize / 2)
                    dragOverlay(xPosition: eyeIconX, isDragging: \.isDraggingVisibility, toggle: toggleVisibility)
                        .padding(.horizontal, 4)
                    dragOverlay(xPosition: lockIconX, isDragging: \.isDraggingLock, toggle: toggleLock)
                        .padding(.horizontal, 4)
                        .zIndex(200)
                }
            }
        }
    }

    private func layerRowContent(for layerIndex: Int) -> some View {
        ProfessionalLayerRow(
            layerIndex: layerIndex,
            layer: layerIndex < document.snapshot.layers.count ? document.snapshot.layers[layerIndex] : Layer(name: "Invalid", objectIDs: []),
            document: document,
            selectedLayerIndex: $selectedLayerIndex
        )
    }

    private func toggleVisibility(for rowType: RowType) {
        switch rowType {
        case .layer(let index):
            if !processedLayersDuringDrag.contains(index) {
                document.snapshot.layers[index].isVisible.toggle()
                processedLayersDuringDrag.insert(index)
                document.triggerLayerUpdate(for: index)
            }
        case .object(let layerIndex, let objectId):
            if !processedObjectsDuringDrag.contains(objectId) {
                if let obj = document.snapshot.objects[objectId] {
                    var updatedShape: VectorShape?
                    switch obj.objectType {
                    case .shape(var shape), .text(var shape), .image(var shape), .group(var shape), .clipGroup(var shape), .warp(var shape), .clipMask(var shape), .guide(var shape):
                        shape.isVisible.toggle()
                        updatedShape = shape
                    }
                    if let shape = updatedShape {
                        let updatedObject = VectorObject(
                            shape: shape,
                            layerIndex: layerIndex
                        )
                        document.snapshot.objects[objectId] = updatedObject
                        processedObjectsDuringDrag.insert(objectId)
                        document.triggerLayerUpdate(for: layerIndex)
                    }
                }
            }
        case .childObject(let layerIndex, _, let childShapeId):
            if !processedObjectsDuringDrag.contains(childShapeId) {
                if let childObj = document.snapshot.objects[childShapeId] {
                    var shape = childObj.shape
                    shape.isVisible.toggle()
                    let updatedObject = VectorObject(
                        id: childShapeId,
                        layerIndex: childObj.layerIndex,
                        objectType: VectorObject.determineType(for: shape)
                    )
                    document.snapshot.objects[childShapeId] = updatedObject
                    processedObjectsDuringDrag.insert(childShapeId)
                    document.triggerLayerUpdate(for: layerIndex)
                }
            }
        }
    }

    private func toggleLock(for rowType: RowType) {
        switch rowType {
        case .layer(let index):
            if !processedLayersDuringDrag.contains(index) {
                document.snapshot.layers[index].isLocked.toggle()
                processedLayersDuringDrag.insert(index)
                document.triggerLayerUpdate(for: index)
            }
        case .object(let layerIndex, let objectId):
            if !processedObjectsDuringDrag.contains(objectId) {
                if let obj = document.snapshot.objects[objectId] {
                    var updatedShape: VectorShape?
                    switch obj.objectType {
                    case .shape(var shape), .text(var shape), .image(var shape), .group(var shape), .clipGroup(var shape), .warp(var shape), .clipMask(var shape), .guide(var shape):
                        shape.isLocked.toggle()
                        updatedShape = shape
                    }
                    if let shape = updatedShape {
                        let updatedObject = VectorObject(
                            shape: shape,
                            layerIndex: layerIndex
                        )
                        document.snapshot.objects[objectId] = updatedObject
                        processedObjectsDuringDrag.insert(objectId)
                        document.triggerLayerUpdate(for: layerIndex)
                    }
                }
            }
        case .childObject(let layerIndex, _, let childShapeId):
            if !processedObjectsDuringDrag.contains(childShapeId) {
                if let childObj = document.snapshot.objects[childShapeId] {
                    var shape = childObj.shape
                    shape.isLocked.toggle()
                    let updatedObject = VectorObject(
                        id: childShapeId,
                        layerIndex: childObj.layerIndex,
                        objectType: VectorObject.determineType(for: shape)
                    )
                    document.snapshot.objects[childShapeId] = updatedObject
                    processedObjectsDuringDrag.insert(childShapeId)
                    document.triggerLayerUpdate(for: layerIndex)
                }
            }
        }
    }
}

struct ColorSwatchButton<Content: View>: View {

    @Binding var color: Color

    let availableColors: [(name: String, color: Color)]
    let buttonContent: () -> Content

    @State private var showColorPicker: Bool = false
    init(
        color: Binding<Color>,
        availableColors: [(name: String, color: Color)],

        @ViewBuilder buttonContent: @escaping () -> Content
    ) {
        self._color = color
        self.availableColors = availableColors
        self.buttonContent = buttonContent
    }

    var body: some View {
        Button(action: {
            showColorPicker = true
        }) {
            buttonContent()
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(availableColors, id: \.name) { colorOption in
                    Button(action: {
                        color = colorOption.color
                        DispatchQueue.main.async {
                            showColorPicker = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(colorOption.color)
                                .padding(.horizontal, -3)
                                .frame(width: 14, height: 16)
                            Text(colorOption.name)
                                .layerText()
                        }
                        .offset(x: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
        }
    }
}

extension ColorSwatchButton where Content == AnyView {

    init(color: Binding<Color>, availableColors: [(name: String, color: Color)]) {
        self._color = color
        self.availableColors = availableColors
        self.buttonContent = {
            AnyView(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.wrappedValue)
                    .padding(.horizontal, -3)
                    .frame(width: 14, height: 16)
            )
        }
    }
}

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

    private func getSelectionBounds() -> CGRect? {
        document.transformFieldSelectionBounds()
    }

    private func applyTransformation() {
        guard let newXInUnit = Double(xValue),
              let newYInUnit = Double(yValue),
              let newWidthInUnit = Double(widthValue),
              let newHeightInUnit = Double(heightValue) else { return }
        document.applyTransformFields(x: currentUnit.toPoints(newXInUnit),
                                      y: currentUnit.toPoints(newYInUnit),
                                      width: currentUnit.toPoints(newWidthInUnit),
                                      height: currentUnit.toPoints(newHeightInUnit))
        updateValuesFromSelection()
    }

    private func applyScale() {
        guard let scaleX = Double(scaleXValue),
              let scaleY = Double(scaleYValue),
              scaleX > 0, scaleY > 0 else { return }
        guard abs(scaleX / 100.0 - 1.0) > 0.001 || abs(scaleY / 100.0 - 1.0) > 0.001 else { return }
        guard getSelectionBounds() != nil else { return }
        document.scaleSelection(percentX: scaleX, percentY: scaleY)
        scaleXValue = "100"
        scaleYValue = "100"
        updateValuesFromSelection()
    }

    private func applyRotation() {
        guard let angle = Double(rotationValue),
              getSelectionBounds() != nil else { return }
        guard abs(angle) > 0.001 else { return }
        document.rotateSelection(degrees: angle)
        rotationValue = "0"
        updateValuesFromSelection()
    }
}

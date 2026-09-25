import SwiftUI

struct GradientLabelStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(Color.ui.secondaryText)
    }
}

struct GradientSubLabelStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.caption2)
            .foregroundColor(Color.ui.secondaryText)
    }
}

struct GradientTextFieldStyle: ViewModifier {
    let width: CGFloat

    func body(content: Content) -> some View {
        content
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: width)
            .font(.system(size: 11))
    }
}

extension View {

    func gradientLabel() -> some View {
        modifier(GradientLabelStyle())
    }

    func gradientSubLabel() -> some View {
        modifier(GradientSubLabelStyle())
    }

    func gradientTextField(width: CGFloat) -> some View {
        modifier(GradientTextFieldStyle(width: width))
    }
}

private struct GradientSliderControl: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let textFieldWidth: CGFloat
    let onChange: (Double) -> Void
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .gradientSubLabel()
            HStack(spacing: 8) {
                Slider(value: Binding(
                    get: { value },
                    set: onChange
                ), in: range, onEditingChanged: onEditingChanged)
                .controlSize(.regular)
                TextField("", text: createNaturalNumberBinding(
                    getValue: { value },
                    setValue: onChange
                ))
                .gradientTextField(width: textFieldWidth)
            }
        }
    }
}

struct GradientTypePickerView: View {

    @Binding var gradientType: GradientFillSection.GradientType
    @Binding var currentGradient: VectorGradient?
    @Binding var gradientId: UUID

    let getGradientStops: (VectorGradient) -> [GradientStop]
    let createGradientPreservingProperties: (GradientFillSection.GradientType, [GradientStop], VectorGradient) -> VectorGradient
    let createDefaultGradient: (GradientFillSection.GradientType) -> VectorGradient
    let onGradientChange: () -> Void

    private func select(_ newType: GradientFillSection.GradientType) {
        gradientType = newType
        if let existing = currentGradient {
            let preservedStops = getGradientStops(existing)
            currentGradient = createGradientPreservingProperties(newType, preservedStops, existing)
        } else {
            currentGradient = createDefaultGradient(newType)
        }
        gradientId = UUID()
        onGradientChange()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .gradientLabel()
            HStack(spacing: 4) {
                ForEach(GradientFillSection.GradientType.allCases, id: \.self) { type in
                    Button {
                        select(type)
                    } label: {
                        Text(type.rawValue)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(gradientType == type ? Color.accentColor : Color.gray.opacity(0.3))
                }
            }
        }
    }
}

struct GradientAngleControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let onAngleChange: (Double) -> Void
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        if let gradient = currentGradient {

            let angle: Double = {
                switch gradient {
                case .linear(let linear):
                    return linear.angle
                case .radial(let radial):
                    return radial.angle
                }
            }()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Angle")
                        .gradientLabel()
                    Spacer()
                    Text("\(formatNumberForDisplay(angle, maxDecimals: 1))°")
                        .gradientLabel()
                }
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { angle },
                        set: { newAngle in
                            onAngleChange(newAngle)
                        }
                    ), in: -180...180, onEditingChanged: onEditingChanged)
                    .controlSize(.regular)
                    TextField("", text: createNaturalNumberBinding(
                        getValue: { angle },
                        setValue: { newAngle in
                            onAngleChange(newAngle)
                        }
                    ))
                    .gradientTextField(width: 60)
                    .onSubmit {
                        onEditingChanged(false)
                    }
                }
            }
        }
    }
}

struct GradientOriginControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let updateOriginX: (Double) -> Void
    let updateOriginY: (Double) -> Void
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        if let gradient = currentGradient {

            let originX: Double = {
                switch gradient {
                case .linear(let linear):
                    return linear.originPoint.x
                case .radial(let radial):
                    return radial.originPoint.x
                }
            }()

            let originY: Double = {
                switch gradient {
                case .linear(let linear):
                    return linear.originPoint.y
                case .radial(let radial):
                    return radial.originPoint.y
                }
            }()
            VStack(alignment: .leading, spacing: 8) {
                Text("Origin Point")
                    .gradientLabel()
                HStack(spacing: 8) {
                    GradientSliderControl(
                        label: "X: \(formatNumberForDisplay(originX))",
                        value: originX,
                        range: 0.0...1.0,
                        textFieldWidth: 50,
                        onChange: updateOriginX,
                        onEditingChanged: onEditingChanged
                    )
                    GradientSliderControl(
                        label: "Y: \(formatNumberForDisplay(originY))",
                        value: originY,
                        range: 0.0...1.0,
                        textFieldWidth: 50,
                        onChange: updateOriginY,
                        onEditingChanged: onEditingChanged
                    )
                }
            }
        }
    }
}

struct GradientScaleControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let getScale: (VectorGradient) -> Double
    let updateScale: (Double) -> Void
    let getAspectRatio: (VectorGradient) -> Double
    let updateAspectRatio: (Double) -> Void
    let getRadius: (VectorGradient) -> Double
    let updateRadius: (Double) -> Void
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scale: \(currentGradient.map { Int(getScale($0) * 100) } ?? 100)%")
                        .gradientLabel()
                    HStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { currentGradient.map { getScale($0) } ?? 1.0 },
                            set: { newScale in
                                updateScale(newScale)
                            }
                        ), in: 0.01...8.0, onEditingChanged: onEditingChanged)
                        .controlSize(.regular)
                        TextField("", text: Binding(
                            get: {
                                let scale = currentGradient.map { getScale($0) } ?? 1.0
                                let percentage = scale * 100
                                return percentage.truncatingRemainder(dividingBy: 1) == 0 ?
                                    String(format: "%.0f", percentage) :
                                    String(format: "%.1f", percentage)
                            },
                            set: { newValue in
                                if let doubleValue = Double(newValue) {
                                    let clamped = max(0, min(800, doubleValue))
                                    updateScale(clamped / 100.0)
                                }
                            }
                        ))
                        .gradientTextField(width: 50)
                    }
                }
                if case .radial = currentGradient {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aspect Ratio: \(currentGradient.map { formatNumberForDisplay(getAspectRatio($0)) } ?? "1")")
                            .gradientLabel()
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient.map { getAspectRatio($0) } ?? 1.0 },
                                set: { newAspectRatio in
                                    updateAspectRatio(newAspectRatio)
                                }
                            ), in: 0.01...2.0, onEditingChanged: onEditingChanged)
                            .controlSize(.regular)
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient.map { getAspectRatio($0) } ?? 1.0 },
                                setValue: updateAspectRatio
                            ))
                            .gradientTextField(width: 50)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Radius: \(currentGradient.map { formatNumberForDisplay(getRadius($0)) } ?? "0.5")")
                            .gradientLabel()
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient.map { getRadius($0) } ?? 0.5 },
                                set: { newRadius in
                                    updateRadius(newRadius)
                                }
                            ), in: 0.1...2.0, onEditingChanged: onEditingChanged)
                            .controlSize(.regular)
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient.map { getRadius($0) } ?? 0.5 },
                                setValue: updateRadius
                            ))
                            .gradientTextField(width: 50)
                        }
                    }
                }
            }
        }
    }
}

struct GradientApplyButtonView: View {
    let currentGradient: VectorGradient?
    let onApply: () -> Void
    let onAddSwatch: () -> Void
    let addColorStop: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button {
                addColorStop()
            } label: {
                Text("Add Stop")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProfessionalSecondaryButtonStyle())
            .onTapGesture {
                addColorStop()
            }
            Button {
                onAddSwatch()
            } label: {
                Text("Add Swatch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProfessionalSecondaryButtonStyle())
            .onTapGesture {
                onAddSwatch()
            }
            Button {
                onApply()
            } label: {
                Text("Apply Gradient")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProfessionalSecondaryButtonStyle())
            .onTapGesture {
                onApply()
            }
        }
    }
}

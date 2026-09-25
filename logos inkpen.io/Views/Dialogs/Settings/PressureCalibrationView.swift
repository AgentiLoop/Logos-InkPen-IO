import SwiftUI
import simd

struct PressureCalibrationView: View {

    @ObservedObject private var pressureManager = PressureManager.shared

    @Environment(\.presentationMode) var presentationMode

    private let appState = AppState.shared

    @State private var currentPressureBarWidth: CGFloat = 0
    @State private var minPressureBarWidth: CGFloat = 0
    @State private var maxPressureBarWidth: CGFloat = 0
    @State private var tabletOnlyMode: Bool = true
    @State private var eventLog: [String] = []

    private let maxEventLogEntries = 20

    @State private var isDrawing = false
    @State private var currentPath: VariableStrokePath?
    @State private var drawingPaths: [VariableStrokePath] = []
    @State private var selectedControlPoint: Int?

    private let barMaxWidth: CGFloat = 280
    private let maxPressureValue: Double = 1.0

    var body: some View {
        VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pressure Calibration")
                            .font(.title2)
                            .fontWeight(.semibold)
                        if tabletOnlyMode {
                            Text("🎯 Tablet/Stylus Mode Active")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Text("🖱️ All Input Devices")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(ProfessionalPrimaryButtonStyle())
                }
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        pressureTestCanvas
                        controlButtonsSection
                    }
                    .frame(minWidth: 800, maxWidth: .infinity)
                    .layoutPriority(2)
                    VStack(spacing: 12) {
                        pressureCurveEditor
                        HStack(spacing: 16) {
                            currentPressureSection
                            pressureRangeSection
                        }
                        .frame(width: 280)
                        pressureVisualizationSection
                        eventLogSection
                    }
                    .frame(width: 320)
                    .layoutPriority(1)
                }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(width: 1200, height: 800)
        .onAppear {
            updateVisualization()
            pressureManager.tabletOnlyCalibration = tabletOnlyMode
            addEventToLog("Pressure calibration tool opened - ready to start")
        }
        .onChange(of: pressureManager.currentPressure) {
            updateVisualization()
        }
    }

    private var pressureCurveEditor: some View {
        VStack(spacing: 8) {
            Text("Pressure Curve")
                .font(.headline)
                .foregroundColor(.primary)
            ZStack {
                Rectangle()
                    .fill(Color.platformControlBackground)
                    .border(Color.gray.opacity(0.3), width: 1)
                Path { path in
                    for i in 0...10 {
                        let x = CGFloat(i) * 28
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: 280))
                    }
                    for i in 0...10 {
                        let y = CGFloat(i) * 28
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: 280, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                Path { path in
                    guard appState.pressureCurve.count >= 2 else { return }
                    let firstPoint = appState.pressureCurve[0]
                    path.move(to: CGPoint(x: firstPoint.x * 280, y: 280 - firstPoint.y * 280))
                    for i in 1..<appState.pressureCurve.count {
                        let point = appState.pressureCurve[i]
                        path.addLine(to: CGPoint(x: point.x * 280, y: 280 - point.y * 280))
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
                ForEach(0..<appState.pressureCurve.count, id: \.self) { index in
                    let point = appState.pressureCurve[index]
                    Circle()
                        .fill(selectedControlPoint == index ? Color.red : Color.blue)
                        .frame(width: 12, height: 12)
                        .position(x: point.x * 280, y: 280 - point.y * 280)
                        .onTapGesture {
                            selectedControlPoint = index
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if selectedControlPoint == index {
                                        let newX = max(0, min(1, value.location.x / 280))
                                        let newY = max(0, min(1, (280 - value.location.y) / 280))
                                        appState.pressureCurve[index] = CGPoint(x: newX, y: newY)
                                        appState.pressureCurve.sort { $0.x < $1.x }
                                        if selectedControlPoint != nil {
                                            selectedControlPoint = appState.pressureCurve.firstIndex { abs($0.x - newX) < 0.01 && abs($0.y - newY) < 0.01 }
                                        }
                                    }
                                }
                        )
                }
            }
            .frame(width: 280, height: 280)
            HStack {
                Text("Input: 0.0-1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Output: 0.0-1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 280)
        .padding(12)
        .background(Color.platformControlBackground)
        .cornerRadius(8)
    }

    @discardableResult
    private func getThicknessFromCurve(pressure: Double) -> Double {
        return getThicknessFromPressureCurve(pressure: pressure, curve: appState.pressureCurve)
    }

    private var pressureTestCanvas: some View {
        VStack(spacing: 6) {
            Text("Pressure-Sensitive Drawing Canvas")
                .font(.subheadline)
                .fontWeight(.medium)
            ZStack {
                Rectangle()
                    .fill(Color.platformControlBackground)
                    .border(Color.gray.opacity(0.3), width: 1)
                VStack {
                    Spacer()
                    Text("Draw here to test pressure sensitivity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                Canvas { context, size in
                    for stroke in drawingPaths {
                        context.fill(stroke.path, with: .color(.blue))
                    }
                    if let currentPath = currentPath, currentPath.points.count >= 2 {
                        let currentStrokePath = createVariableWidthStroke(from: currentPath.points)
                        context.fill(currentStrokePath, with: .color(.red))
                    } else if let currentPath = currentPath, currentPath.points.count == 1 {
                        let point = currentPath.points[0]
                        let radius = CGFloat(0.1 + (point.pressure * 0.9)) / 2.0
                        let circlePath = Path { path in
                            path.addEllipse(in: CGRect(x: point.location.x - radius, y: point.location.y - radius, width: radius * 2, height: radius * 2))
                        }
                        context.fill(circlePath, with: .color(.red))
                    }
                    if isDrawing {
                        let normalizedPressure = max(0.0, min(1.0, pressureManager.currentPressure / 2.0))
                        let thickness = 0.1 + (normalizedPressure * 0.9)
                        let pressureText = String(format: "Pressure: %.2f (Width: %.1f)", normalizedPressure, thickness)
                        context.draw(Text(pressureText).font(.caption).foregroundColor(.black), at: CGPoint(x: 10, y: size.height - 30))
                    }
                }
                .drawingGroup()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrawingGesture(value)
                        }
                        .onEnded { _ in
                            finishDrawing()
                        }
                )
                .frame(minHeight: 500)
                PressureSensitiveCanvasRepresentable(
                    onPressureEvent: { location, pressure, eventType, isTabletEvent in
                        pressureManager.processRealPressure(pressure, at: location, isTabletEvent: isTabletEvent)
                        handlePressureDrawing(location: location, pressure: pressure, eventType: eventType, isTabletEvent: isTabletEvent)
                        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        let logEntry = "[\(timestamp)] \(eventType) - Pressure: \(String(format: "%.3f", pressure)) - Tablet: \(isTabletEvent) - Loc: (\(Int(location.x)), \(Int(location.y)))"
                        DispatchQueue.main.async {
                            eventLog.insert(logEntry, at: 0)
                            if eventLog.count > maxEventLogEntries {
                                eventLog.removeLast()
                            }
                        }
                    },
                    hasPressureSupport: .constant(false)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .background(Color.platformControlBackground)
        .cornerRadius(8)
    }

    private func handlePressureDrawing(location: CGPoint, pressure: Double, eventType: PressureSensitiveCanvasView.PressureEventType, isTabletEvent: Bool) {
        switch eventType {
        case .began:
            startDrawing(at: location, pressure: pressure)
        case .changed:
            continueDrawing(to: location, pressure: pressure)
        case .ended:
            finishDrawing()
        }
    }

    private func handleDrawingGesture(_ value: DragGesture.Value) {
        let pressure = 1.0
        let location = value.location
        if !isDrawing {
            startDrawing(at: location, pressure: pressure)
        } else {
            continueDrawing(to: location, pressure: pressure)
        }
    }

    private func startDrawing(at location: CGPoint, pressure: Double) {
        isDrawing = true
        getThicknessFromCurve(pressure: pressure)
        currentPath = VariableStrokePath(points: [PressurePoint(location: location, pressure: pressure)])
        if !pressureManager.isCalibrating {
            pressureManager.startCalibration()
        }
    }

    private func continueDrawing(to location: CGPoint, pressure: Double) {
        guard isDrawing, var path = currentPath else { return }
        getThicknessFromCurve(pressure: pressure)
        path.points.append(PressurePoint(location: location, pressure: pressure))
        currentPath = path
        updateCanvas()
    }

    private func finishDrawing() {
        guard isDrawing, let path = currentPath else { return }
        let strokePath = createVariableWidthStroke(from: path.points)

        var completedStroke = VariableStrokePath(points: path.points)
        completedStroke.path = strokePath
        drawingPaths.append(completedStroke)
        isDrawing = false
        currentPath = nil
        updateCanvas()
    }

    private func clearCanvas() {
        drawingPaths.removeAll()
        currentPath = nil
        isDrawing = false
        updateCanvas()
    }

    private func updateCanvas() {
    }

    private func createVariableWidthStroke(from pressurePoints: [PressurePoint]) -> Path {
        guard pressurePoints.count >= 2 else {
            guard let point = pressurePoints.first else {
                return Path()
            }
            let curveThickness = getThicknessFromCurve(pressure: point.pressure)
            let radius = CGFloat(curveThickness * 10.0) * 1.0
            return Path { path in
                path.addEllipse(in: CGRect(x: point.location.x - radius, y: point.location.y - radius,
                                          width: radius * 2, height: radius * 2))
            }
        }
        var path = Path()
        var leftEdgePoints: [CGPoint] = []
        var rightEdgePoints: [CGPoint] = []
        for i in 0..<pressurePoints.count {
            let point = pressurePoints[i]
            let curveThickness = getThicknessFromCurve(pressure: point.pressure)
            let thickness = CGFloat(curveThickness * 10.0) * 2.0
            if i == 0 {
                let nextPoint = pressurePoints[i + 1]
                let pointVec = SIMD2<Double>(Double(point.location.x), Double(point.location.y))
                let nextVec = SIMD2<Double>(Double(nextPoint.location.x), Double(nextPoint.location.y))
                let direction = nextVec - pointVec
                let length = simd_length(direction)
                if length > 0 {
                    let normalized = simd_normalize(direction)
                    let perpendicular = SIMD2<Double>(-normalized.y, normalized.x)
                    let leftEdge = pointVec + perpendicular * thickness
                    let rightEdge = pointVec - perpendicular * thickness
                    leftEdgePoints.append(CGPoint(x: leftEdge.x, y: leftEdge.y))
                    rightEdgePoints.append(CGPoint(x: rightEdge.x, y: rightEdge.y))
                } else {
                    leftEdgePoints.append(point.location)
                    rightEdgePoints.append(point.location)
                }
            } else if i == pressurePoints.count - 1 {
                let prevPoint = pressurePoints[i - 1]
                let pointVec = SIMD2<Double>(Double(point.location.x), Double(point.location.y))
                let prevVec = SIMD2<Double>(Double(prevPoint.location.x), Double(prevPoint.location.y))
                let direction = pointVec - prevVec
                let length = simd_length(direction)
                if length > 0 {
                    let normalized = simd_normalize(direction)
                    let perpendicular = SIMD2<Double>(-normalized.y, normalized.x)
                    let leftEdge = pointVec + perpendicular * thickness
                    let rightEdge = pointVec - perpendicular * thickness
                    leftEdgePoints.append(CGPoint(x: leftEdge.x, y: leftEdge.y))
                    rightEdgePoints.append(CGPoint(x: rightEdge.x, y: rightEdge.y))
                } else {
                    leftEdgePoints.append(point.location)
                    rightEdgePoints.append(point.location)
                }
            } else {
                let prevPoint = pressurePoints[i - 1]
                let nextPoint = pressurePoints[i + 1]
                let pointVec = SIMD2<Double>(Double(point.location.x), Double(point.location.y))
                let prevVec = SIMD2<Double>(Double(prevPoint.location.x), Double(prevPoint.location.y))
                let nextVec = SIMD2<Double>(Double(nextPoint.location.x), Double(nextPoint.location.y))
                let prevDirection = pointVec - prevVec
                let nextDirection = nextVec - pointVec
                let avgDirection = (prevDirection + nextDirection) / 2.0
                let length = simd_length(avgDirection)
                if length > 0 {
                    let normalized = simd_normalize(avgDirection)
                    let perpendicular = SIMD2<Double>(-normalized.y, normalized.x)
                    let leftEdge = pointVec + perpendicular * thickness
                    let rightEdge = pointVec - perpendicular * thickness
                    leftEdgePoints.append(CGPoint(x: leftEdge.x, y: leftEdge.y))
                    rightEdgePoints.append(CGPoint(x: rightEdge.x, y: rightEdge.y))
                } else {
                    leftEdgePoints.append(point.location)
                    rightEdgePoints.append(point.location)
                }
            }
        }
        if leftEdgePoints.count >= 2 && rightEdgePoints.count >= 2 {
            path.move(to: leftEdgePoints[0])
            for i in 1..<leftEdgePoints.count {
                path.addLine(to: leftEdgePoints[i])
            }
            for i in (0..<rightEdgePoints.count).reversed() {
                path.addLine(to: rightEdgePoints[i])
            }
            path.closeSubpath()
        }
        return path
    }

    private var currentPressureSection: some View {
        VStack(spacing: 6) {
            Text("Current (0-1)")
                .font(.caption)
                .foregroundColor(.secondary)
            let rawPressure = pressureManager.isCalibrating ? pressureManager.currentPressure : 0.0
            Text(String(format: "%.3f", rawPressure))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .monospaced()
        }
        .padding(12)
        .background(Color.platformControlBackground)
        .cornerRadius(8)
    }

    private var pressureRangeSection: some View {
        VStack(spacing: 8) {
            Text("Range (0-1)")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    let rawMin = pressureManager.isCalibrating ? pressureManager.calibrationMinPressure : 0.0
                    Text(String(format: "%.3f", rawMin))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .monospaced()
                }
                VStack(spacing: 2) {
                    Text("Max")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    let rawMax = pressureManager.isCalibrating ? pressureManager.calibrationMaxPressure : 0.0
                    Text(String(format: "%.3f", rawMax))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .monospaced()
                }
                VStack(spacing: 2) {
                    Text("Samples")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(pressureManager.calibrationSampleCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .monospaced()
                }
            }
        }
        .padding(12)
        .background(Color.platformControlBackground)
        .cornerRadius(8)
    }

    private var pressureVisualizationSection: some View {
        VStack(spacing: 12) {
            Text("Pressure Visualization")
                .font(.headline)
            VStack(spacing: 8) {
                HStack {
                    Text("Current:")
                        .font(.caption)
                        .frame(width: 60, alignment: .trailing)
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: barMaxWidth, height: 20)
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: currentPressureBarWidth, height: 20)
                            .animation(.easeInOut(duration: 0.1), value: currentPressureBarWidth)
                    }
                    .cornerRadius(4)
                }
                HStack {
                    Text("Min:")
                        .font(.caption)
                        .frame(width: 60, alignment: .trailing)
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: barMaxWidth, height: 15)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: minPressureBarWidth, height: 15)
                    }
                    .cornerRadius(4)
                }
                HStack {
                    Text("Max:")
                        .font(.caption)
                        .frame(width: 60, alignment: .trailing)
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: barMaxWidth, height: 15)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: maxPressureBarWidth, height: 15)
                    }
                    .cornerRadius(4)
                }
            }
        }
        .frame(width: 280)
        .padding()
        .background(Color.platformControlBackground)
        .cornerRadius(8)
    }

    private var eventLogSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Event Log")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    eventLog.removeAll()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(eventLog, id: \.self) { logEntry in
                        Text(logEntry)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(height: 80)
            .padding(8)
            .background(Color.platformControlBackground)
            .border(Color.gray.opacity(0.3), width: 1)
            .cornerRadius(4)
        }
        .frame(width: 280)
        .padding()
        .background(Color.platformControlBackground)
        .cornerRadius(8)
    }

    private var controlButtonsSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: tabletOnlyMode ? "checkmark.square.fill" : "square")
                    .foregroundColor(tabletOnlyMode ? .blue : .gray)
                    .onTapGesture {
                        tabletOnlyMode.toggle()
                        pressureManager.tabletOnlyCalibration = tabletOnlyMode
                    }
                Text("Tablet Only")
                    .font(.caption)
                    .onTapGesture {
                        tabletOnlyMode.toggle()
                        pressureManager.tabletOnlyCalibration = tabletOnlyMode
                    }
            }
            Button(action: {
                if pressureManager.isCalibrating {
                    pressureManager.stopCalibration()
                } else {
                    pressureManager.startCalibration()
                }
            }) {
                Text(pressureManager.isCalibrating ? "Stop" : "Start")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(pressureManager.isCalibrating ? Color.red : Color.blue)
                    .cornerRadius(6)
            }
            .buttonStyle(BorderlessButtonStyle())
            Button(action: {
                pressureManager.resetCalibration()
                pressureManager.calibrationMinPressure = 0.0
                pressureManager.calibrationMaxPressure = 0.0
                addEventToLog("Reset calibration data - Min and Max set to 0.0")
            }) {
                Text("Reset")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray)
                    .cornerRadius(6)
            }
            .buttonStyle(BorderlessButtonStyle())
            Button(action: {
                clearCanvas()
            }) {
                Text("Clear Canvas")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }

    private func closeCalibration() {
        if pressureManager.isCalibrating {
            pressureManager.stopCalibration()
        }
        presentationMode.wrappedValue.dismiss()
    }

    private func addEventToLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        DispatchQueue.main.async {
            eventLog.insert(logEntry, at: 0)
            if eventLog.count > maxEventLogEntries {
                eventLog.removeLast()
            }
        }
    }

    private func updateVisualization() {
        let rawCurrentPressure = pressureManager.isCalibrating ? pressureManager.currentPressure : 0.0
        let rawMinPressure = pressureManager.isCalibrating ? pressureManager.calibrationMinPressure : 0.0
        let rawMaxPressure = pressureManager.isCalibrating ? pressureManager.calibrationMaxPressure : 0.0
        currentPressureBarWidth = CGFloat(rawCurrentPressure) * barMaxWidth
        minPressureBarWidth = CGFloat(rawMinPressure) * barMaxWidth
        maxPressureBarWidth = CGFloat(rawMaxPressure) * barMaxWidth
    }
}

struct PressurePoint {
    let location: CGPoint
    let pressure: Double
}

struct VariableStrokePath {
    var points: [PressurePoint]
    var path: Path = Path()
}

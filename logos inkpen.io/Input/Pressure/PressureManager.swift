import SwiftUI
import Combine

class PressureManager: ObservableObject {

    @Published var hasRealPressureInput = false
    @Published var currentPressure: Double = 1.0
    @Published var isCalibrating = false
    @Published var calibrationMinPressure: Double = 0.0
    @Published var calibrationMaxPressure: Double = 0.0
    @Published var calibrationSampleCount: Int = 0
    @Published var tabletOnlyCalibration: Bool = true

    private var lastLocation: CGPoint?
    private var lastTimestamp: Date?
    private var lastRecordedPressure: Double?
    private var recentPressureValues: [Double] = []

    private let pressureHistorySize = 10
    private let pressureVariationThreshold = 0.01
    private let maxSpeed: Double = 100.0
    private let speedSmoothingFactor: Double = 0.3

    init() {
        detectInitialPressureSupport()
    }

    private func detectInitialPressureSupport() {
        hasRealPressureInput = false
    }

    func updatePressureSupport(_ isSupported: Bool) {
        DispatchQueue.main.async {
            self.hasRealPressureInput = isSupported
        }
    }

    func processRealPressure(_ pressure: Double, at location: CGPoint, timestamp: Date = Date(), isTabletEvent: Bool = false) {
        if isCalibrating && tabletOnlyCalibration && !isTabletEvent {
            return
        }
        recentPressureValues.append(pressure)
        if recentPressureValues.count > pressureHistorySize {
            recentPressureValues.removeFirst()
        }
        if recentPressureValues.count >= pressureHistorySize {
            let shouldHaveReal = !isPressureConstant()
            if hasRealPressureInput != shouldHaveReal {
                updatePressureSupport(shouldHaveReal)
            }
        }
        if Thread.isMainThread {
            self.currentPressure = pressure
        } else {
            DispatchQueue.main.sync {
                self.currentPressure = pressure
            }
        }
        lastLocation = location
        lastTimestamp = timestamp
        if isCalibrating {
            updateCalibrationData(pressure: pressure, isTabletEvent: isTabletEvent)
        }
        if let lastPressure = lastRecordedPressure, abs(pressure - lastPressure) > 0.1 {
            lastRecordedPressure = pressure
        } else if lastRecordedPressure == nil {
            lastRecordedPressure = pressure
        }
    }

    func processSimulatedPressure(at location: CGPoint, sensitivity: Double = 0.5, timestamp: Date = Date()) -> Double {
        let simulatedPressure = calculateSimulatedPressure(at: location, timestamp: timestamp, sensitivity: sensitivity)
        DispatchQueue.main.async {
            self.currentPressure = simulatedPressure
        }
        return simulatedPressure
    }

    private func calculateSimulatedPressure(at location: CGPoint, timestamp: Date, sensitivity: Double) -> Double {
        defer {
            lastLocation = location
            lastTimestamp = timestamp
        }
        guard let lastLoc = lastLocation, let lastTime = lastTimestamp else {
            return 1.0
        }
        let distance = location.distance(to: lastLoc)
        let timeInterval = timestamp.timeIntervalSince(lastTime)
        guard timeInterval > 0 else { return currentPressure }
        let speed = distance / timeInterval
        let normalizedSpeed = min(speed / maxSpeed, 1.0)
        let pressureRange = sensitivity
        let basePressure = 1.0 - (normalizedSpeed * pressureRange)
        let finalPressure = max(0.1, min(1.0, basePressure))
        let smoothedPressure = (currentPressure * (1.0 - speedSmoothingFactor)) + (finalPressure * speedSmoothingFactor)
        return smoothedPressure
    }

    private func isPressureConstant() -> Bool {
        guard recentPressureValues.count >= pressureHistorySize else {
            return false
        }
        let minPressure = recentPressureValues.min() ?? 0
        let maxPressure = recentPressureValues.max() ?? 0
        let variation = maxPressure - minPressure
        return variation < pressureVariationThreshold
    }

    func resetForNewDrawing() {
        lastLocation = nil
        lastTimestamp = nil
        lastRecordedPressure = nil
        currentPressure = 1.0
        recentPressureValues.removeAll()
    }

    func getPressure(for location: CGPoint, sensitivity: Double = 0.5) -> Double {
        if hasRealPressureInput {
            if isPressureConstant() {
                return processSimulatedPressure(at: location, sensitivity: sensitivity)
            } else {
                return currentPressure
            }
        } else {
            return processSimulatedPressure(at: location, sensitivity: sensitivity)
        }
    }

    func startCalibration() {
        DispatchQueue.main.async {
            self.isCalibrating = true
            self.calibrationMinPressure = 0.0
            self.calibrationMaxPressure = 0.0
            self.calibrationSampleCount = 0
        }
    }

    func stopCalibration() {
        DispatchQueue.main.async {
            self.isCalibrating = false
        }
    }

    func resetCalibration() {
        DispatchQueue.main.async {
            self.calibrationMinPressure = 0.0
            self.calibrationMaxPressure = 0.0
            self.calibrationSampleCount = 0
        }
    }

    private func updateCalibrationData(pressure: Double, isTabletEvent: Bool = false) {
        DispatchQueue.main.async {
            self.calibrationSampleCount += 1
        }
    }
}

extension PressureManager {
    static let shared = PressureManager()
}

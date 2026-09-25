import SwiftUI
import Combine

enum AlignmentAnchorMode: String, CaseIterable {
    case firstSelected = "firstSelected"
    case lastSelected = "lastSelected"
    case largestArea = "largestArea"
    case smallestArea = "smallestArea"

    var displayName: String {
        switch self {
        case .firstSelected: return "First Selected"
        case .lastSelected: return "Last Selected"
        case .largestArea: return "Largest Area"
        case .smallestArea: return "Smallest Area"
        }
    }
}

class ApplicationSettings: ObservableObject {
    static let shared = ApplicationSettings()

    @Published var currentBrushThickness: Double = UserDefaults.standard.object(forKey: "brushThickness") as? Double ?? 20.0 {
        didSet { UserDefaults.standard.set(currentBrushThickness, forKey: "brushThickness") }
    }

    @Published var currentBrushSmoothingTolerance: Double = UserDefaults.standard.object(forKey: "brushSmoothingTolerance") as? Double ?? 5.0 {
        didSet { UserDefaults.standard.set(currentBrushSmoothingTolerance, forKey: "brushSmoothingTolerance") }
    }

    @Published var currentBrushMinTaperThickness: Double = UserDefaults.standard.object(forKey: "brushMinTaperThickness") as? Double ?? 0.5 {
        didSet { UserDefaults.standard.set(currentBrushMinTaperThickness, forKey: "brushMinTaperThickness") }
    }

    @Published var currentBrushTaperStart: Double = UserDefaults.standard.object(forKey: "brushTaperStart") as? Double ?? 0.15 {
        didSet { UserDefaults.standard.set(currentBrushTaperStart, forKey: "brushTaperStart") }
    }

    @Published var currentBrushTaperEnd: Double = UserDefaults.standard.object(forKey: "brushTaperEnd") as? Double ?? 0.15 {
        didSet { UserDefaults.standard.set(currentBrushTaperEnd, forKey: "brushTaperEnd") }
    }

    @Published var brushApplyNoStroke: Bool = UserDefaults.standard.object(forKey: "brushApplyNoStroke") as? Bool ?? true {
        didSet { UserDefaults.standard.set(brushApplyNoStroke, forKey: "brushApplyNoStroke") }
    }

    @Published var brushRemoveOverlap: Bool = UserDefaults.standard.object(forKey: "brushRemoveOverlap") as? Bool ?? true {
        didSet { UserDefaults.standard.set(brushRemoveOverlap, forKey: "brushRemoveOverlap") }
    }

    @Published var brushCoincidentPointPasses: Int = UserDefaults.standard.object(forKey: "brushCoincidentPointPasses") as? Int ?? 1 {
        didSet { UserDefaults.standard.set(brushCoincidentPointPasses, forKey: "brushCoincidentPointPasses") }
    }

    @Published var advancedSmoothingEnabled: Bool = UserDefaults.standard.object(forKey: "advancedSmoothingEnabled") as? Bool ?? false {
        didSet { UserDefaults.standard.set(advancedSmoothingEnabled, forKey: "advancedSmoothingEnabled") }
    }

    @Published var chaikinSmoothingIterations: Int = UserDefaults.standard.object(forKey: "chaikinSmoothingIterations") as? Int ?? 1 {
        didSet { UserDefaults.standard.set(chaikinSmoothingIterations, forKey: "chaikinSmoothingIterations") }
    }

    @Published var freehandSmoothingTolerance: Double = UserDefaults.standard.object(forKey: "freehandSmoothingTolerance") as? Double ?? 2.0 {
        didSet { UserDefaults.standard.set(freehandSmoothingTolerance, forKey: "freehandSmoothingTolerance") }
    }

    @Published var realTimeSmoothingEnabled: Bool = UserDefaults.standard.object(forKey: "realTimeSmoothingEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(realTimeSmoothingEnabled, forKey: "realTimeSmoothingEnabled") }
    }

    @Published var realTimeSmoothingStrength: Double = UserDefaults.standard.object(forKey: "realTimeSmoothingStrength") as? Double ?? 0.3 {
        didSet { UserDefaults.standard.set(realTimeSmoothingStrength, forKey: "realTimeSmoothingStrength") }
    }

    @Published var preserveSharpCorners: Bool = UserDefaults.standard.object(forKey: "preserveSharpCorners") as? Bool ?? true {
        didSet { UserDefaults.standard.set(preserveSharpCorners, forKey: "preserveSharpCorners") }
    }

    @Published var freehandFillMode: VectorDocument.FreehandFillMode = VectorDocument.FreehandFillMode(rawValue: UserDefaults.standard.string(forKey: "freehandFillMode") ?? "No Fill") ?? .noFill {
        didSet { UserDefaults.standard.set(freehandFillMode.rawValue, forKey: "freehandFillMode") }
    }

    @Published var freehandExpandStroke: Bool = UserDefaults.standard.object(forKey: "freehandExpandStroke") as? Bool ?? false {
        didSet { UserDefaults.standard.set(freehandExpandStroke, forKey: "freehandExpandStroke") }
    }

    @Published var freehandClosePath: Bool = UserDefaults.standard.object(forKey: "freehandClosePath") as? Bool ?? false {
        didSet { UserDefaults.standard.set(freehandClosePath, forKey: "freehandClosePath") }
    }

    @Published var currentMarkerSmoothingTolerance: Double = UserDefaults.standard.object(forKey: "markerSmoothingTolerance") as? Double ?? 20.0 {
        didSet { UserDefaults.standard.set(currentMarkerSmoothingTolerance, forKey: "markerSmoothingTolerance") }
    }

    @Published var currentMarkerTipSize: Double = UserDefaults.standard.object(forKey: "markerTipSize") as? Double ?? 31.0 {
        didSet { UserDefaults.standard.set(currentMarkerTipSize, forKey: "markerTipSize") }
    }

    @Published var currentMarkerOpacity: Double = UserDefaults.standard.object(forKey: "markerOpacity") as? Double ?? 1.0 {
        didSet { UserDefaults.standard.set(currentMarkerOpacity, forKey: "markerOpacity") }
    }

    @Published var currentMarkerFeathering: Double = UserDefaults.standard.object(forKey: "markerFeathering") as? Double ?? 0.3 {
        didSet { UserDefaults.standard.set(currentMarkerFeathering, forKey: "markerFeathering") }
    }

    @Published var currentMarkerTaperStart: Double = UserDefaults.standard.object(forKey: "markerTaperStart") as? Double ?? 0.1 {
        didSet { UserDefaults.standard.set(currentMarkerTaperStart, forKey: "markerTaperStart") }
    }

    @Published var currentMarkerTaperEnd: Double = UserDefaults.standard.object(forKey: "markerTaperEnd") as? Double ?? 0.1 {
        didSet { UserDefaults.standard.set(currentMarkerTaperEnd, forKey: "markerTaperEnd") }
    }

    @Published var currentMarkerMinTaperThickness: Double = UserDefaults.standard.object(forKey: "markerMinTaperThickness") as? Double ?? 2.0 {
        didSet { UserDefaults.standard.set(currentMarkerMinTaperThickness, forKey: "markerMinTaperThickness") }
    }

    @Published var markerUseFillAsStroke: Bool = UserDefaults.standard.object(forKey: "markerUseFillAsStroke") as? Bool ?? true {
        didSet { UserDefaults.standard.set(markerUseFillAsStroke, forKey: "markerUseFillAsStroke") }
    }

    @Published var markerApplyNoStroke: Bool = UserDefaults.standard.object(forKey: "markerApplyNoStroke") as? Bool ?? false {
        didSet { UserDefaults.standard.set(markerApplyNoStroke, forKey: "markerApplyNoStroke") }
    }

    @Published var markerRemoveOverlap: Bool = UserDefaults.standard.object(forKey: "markerRemoveOverlap") as? Bool ?? true {
        didSet { UserDefaults.standard.set(markerRemoveOverlap, forKey: "markerRemoveOverlap") }
    }

    @Published var liveScalingPreview: Bool = UserDefaults.standard.object(forKey: "liveScalingPreview") as? Bool ?? false {
        didSet { UserDefaults.standard.set(liveScalingPreview, forKey: "liveScalingPreview") }
    }

    @Published var hideTransformBoxDuringDrag: Bool = UserDefaults.standard.object(forKey: "hideTransformBoxDuringDrag") as? Bool ?? false {
        didSet { UserDefaults.standard.set(hideTransformBoxDuringDrag, forKey: "hideTransformBoxDuringDrag") }
    }

    @Published var boundingBoxIncludesStrokes: Bool = UserDefaults.standard.object(forKey: "boundingBoxIncludesStrokes") as? Bool ?? true {
        didSet { UserDefaults.standard.set(boundingBoxIncludesStrokes, forKey: "boundingBoxIncludesStrokes") }
    }

    @Published var embedImagesByDefault: Bool = UserDefaults.standard.object(forKey: "embedImagesByDefault") as? Bool ?? false {
        didSet { UserDefaults.standard.set(embedImagesByDefault, forKey: "embedImagesByDefault") }
    }

    @Published var alignmentAnchorMode: AlignmentAnchorMode = AlignmentAnchorMode(rawValue: UserDefaults.standard.string(forKey: "alignmentAnchorMode") ?? "firstSelected") ?? .firstSelected {
        didSet { UserDefaults.standard.set(alignmentAnchorMode.rawValue, forKey: "alignmentAnchorMode") }
    }

    @Published var importFreeHandEffects: Bool = UserDefaults.standard.object(forKey: "importFreeHandEffects") as? Bool ?? true {
        didSet { UserDefaults.standard.set(importFreeHandEffects, forKey: "importFreeHandEffects") }
    }

    private init() {}
}

import CoreGraphics

/// Pure, UI-free math for canvas navigation and nudging, kept separate so it can be unit tested.
enum ZoomMath {
    static let minZoom: CGFloat = 0.1
    static let maxZoom: CGFloat = 640.0

    /// Discrete stops used by Cmd+/Cmd-, the zoom tool click, and quantizing.
    /// Starts at 10% so "Fit to Page" on large artboards can still be stepped out/in.
    static let steps: [CGFloat] = [
        0.1, 0.125, 0.167, 0.25, 0.333, 0.5, 0.667, 0.75, 0.8, 0.9, 1.0,
        1.25, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
        13.0, 14.0, 15.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 640.0
    ]

    static func clamp(_ zoom: CGFloat) -> CGFloat {
        guard zoom.isFinite else { return 1.0 }
        return max(minZoom, min(maxZoom, zoom))
    }

    static func nearestStep(to zoom: CGFloat) -> CGFloat {
        let clamped = clamp(zoom)
        return steps.min(by: { abs($0 - clamped) < abs($1 - clamped) }) ?? 1.0
    }

    static func stepUp(from zoom: CGFloat) -> CGFloat {
        let epsilon: CGFloat = 1e-6
        return steps.first(where: { $0 > zoom + epsilon }) ?? maxZoom
    }

    static func stepDown(from zoom: CGFloat) -> CGFloat {
        let epsilon: CGFloat = 1e-6
        return steps.last(where: { $0 < zoom - epsilon }) ?? minZoom
    }
}

enum NudgeMath {
    /// Illustrator's default keyboard increment is 1 pt; Shift = 10x, Option = 0.1x.
    /// When snap-to-grid is on the increment is one grid step so objects stay on grid.
    static func increment(gridSpacingInPoints: CGFloat, snapToGrid: Bool, shift: Bool, option: Bool) -> CGFloat {
        let base: CGFloat = (snapToGrid && gridSpacingInPoints > 0) ? gridSpacingInPoints : 1.0
        if shift { return base * 10.0 }
        if option { return base * 0.1 }
        return base
    }
}

enum HitTestMath {
    /// Screen-space hit slop in points; divided by zoom so it feels the same at every magnification.
    static let screenTolerance: CGFloat = 4.0

    static func canvasTolerance(zoom: CGFloat) -> CGFloat {
        let z = zoom.isFinite && zoom > 0 ? zoom : 1.0
        return screenTolerance / z
    }

    /// True if `point` hits the filled interior (when `filled`) or lies within the stroke
    /// band (half stroke width + tolerance) of `path`. Both are in the same coordinate space.
    static func hits(path: CGPath, point: CGPoint, filled: Bool, fillRule: CGPathFillRule,
                     strokeWidth: CGFloat, tolerance: CGFloat) -> Bool {
        guard point.x.isFinite, point.y.isFinite, !path.isEmpty else { return false }
        let halfBand = max(0, strokeWidth) / 2 + max(0, tolerance)
        let box = path.boundingBoxOfPath.insetBy(dx: -halfBand, dy: -halfBand)
        guard box.contains(point) else { return false }
        if filled && path.contains(point, using: fillRule) { return true }
        let band = path.copy(strokingWithWidth: halfBand * 2, lineCap: .round, lineJoin: .round, miterLimit: 10)
        return band.contains(point)
    }
}

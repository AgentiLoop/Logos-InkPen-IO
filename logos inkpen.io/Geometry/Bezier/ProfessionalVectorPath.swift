import SwiftUI

struct ProfessionalVectorPath: Codable, Hashable, Identifiable {
    var id: UUID
    var points: [ProfessionalBezierMathematics.BezierPoint]
    var isClosed: Bool
    var pathStyle: PathStyle
    var continuityConstraints: [ContinuityConstraint]

    struct PathStyle: Codable, Hashable {
        var tension: Double = 0.33
        var handleVisibility: HandleVisibility = .selected
        var snapToGrid: Bool = false
        var smartGuides: Bool = true
        var precisionMode: Bool = false

        enum HandleVisibility: String, Codable, CaseIterable {
            case never = "Never"
            case selected = "Selected"
            case always = "Always"
            case onHover = "On Hover"
        }
    }

    struct ContinuityConstraint: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var pointIndex: Int
        var continuityType: ProfessionalBezierMathematics.ContinuityType
        var isLocked: Bool = false
        var tolerance: Double = 1e-6
    }

    init(points: [ProfessionalBezierMathematics.BezierPoint] = [],
         isClosed: Bool = false,
         pathStyle: PathStyle = PathStyle()) {
        self.id = UUID()
        self.points = points
        self.isClosed = isClosed
        self.pathStyle = pathStyle
        self.continuityConstraints = []
        if points.count > 1 {
            for i in 0..<points.count - 1 {
                continuityConstraints.append(ContinuityConstraint(
                    pointIndex: i,
                    continuityType: .g1
                ))
            }
        }
    }

    mutating func addPoint(_ point: ProfessionalBezierMathematics.BezierPoint) {
        points.append(point)
        if points.count > 1 {
            continuityConstraints.append(ContinuityConstraint(
                pointIndex: points.count - 2,
                continuityType: .g1
            ))
        }
    }

    mutating func insertPoint(_ point: ProfessionalBezierMathematics.BezierPoint, at index: Int) {
        guard index >= 0 && index <= points.count else { return }
        if index == points.count {
            addPoint(point)
            return
        }
        points.insert(point, at: index)
        regenerateContinuityConstraints()
    }

    mutating func removePoint(at index: Int) {
        guard index >= 0 && index < points.count else { return }
        points.remove(at: index)
        regenerateContinuityConstraints()
    }

    mutating func updatePoint(at index: Int, newPoint: ProfessionalBezierMathematics.BezierPoint, maintainContinuity: Bool = true) {
        guard index >= 0 && index < points.count else { return }
        points[index] = newPoint
        if maintainContinuity {
            enforceLocalContinuity(at: index)
        }
    }

    mutating func close() {
        guard !isClosed && points.count >= 3 else { return }
        isClosed = true
        continuityConstraints.append(ContinuityConstraint(
            pointIndex: points.count - 1,
            continuityType: .g1
        ))
        enforceClosingContinuity()
    }

    mutating func open() {
        guard isClosed else { return }
        isClosed = false
        continuityConstraints.removeAll { $0.pointIndex == points.count - 1 }
    }

    mutating func generateSmoothHandles() {
        for i in 0..<points.count {
            let previousPoint = (i > 0) ? points[i - 1].point : (isClosed ? points.last?.point : nil)
            let nextPoint = (i < points.count - 1) ? points[i + 1].point : (isClosed ? points.first?.point : nil)
            if points[i].pointType == .smoothCurve || points[i].pointType == .smoothCorner {
                let (incomingHandle, outgoingHandle) = ProfessionalBezierMathematics.generateSmoothHandles(
                    previousPoint: previousPoint,
                    currentPoint: points[i].point,
                    nextPoint: nextPoint,
                    tension: pathStyle.tension
                )
                points[i].incomingHandle = incomingHandle
                points[i].outgoingHandle = outgoingHandle
            }
        }
    }

    mutating func convertPointType(at index: Int, to newType: ProfessionalBezierMathematics.AnchorPointType) {
        guard index >= 0 && index < points.count else { return }
        let oldPoint = points[index]

        var newPoint = oldPoint
        newPoint.pointType = newType
        switch newType {
        case .corner:
            newPoint.incomingHandle = nil
            newPoint.outgoingHandle = nil
            newPoint.handleConstraint = .independent
        case .smoothCurve:
            newPoint.handleConstraint = .symmetric
            generateHandlesForPoint(at: index, pointType: newType)
        case .smoothCorner:
            newPoint.handleConstraint = .aligned
            generateHandlesForPoint(at: index, pointType: newType)
        case .cusp:
            newPoint.handleConstraint = .independent
        case .connector:
            newPoint.handleConstraint = .automatic
            generateHandlesForPoint(at: index, pointType: newType)
        }
        points[index] = newPoint
    }

    private mutating func generateHandlesForPoint(at index: Int, pointType: ProfessionalBezierMathematics.AnchorPointType) {
        guard index >= 0 && index < points.count else { return }
        let previousPoint = (index > 0) ? points[index - 1].point : (isClosed ? points.last?.point : nil)
        let nextPoint = (index < points.count - 1) ? points[index + 1].point : (isClosed ? points.first?.point : nil)
        let (incomingHandle, outgoingHandle) = ProfessionalBezierMathematics.generateSmoothHandles(
            previousPoint: previousPoint,
            currentPoint: points[index].point,
            nextPoint: nextPoint,
            tension: pathStyle.tension
        )
        switch pointType {
        case .smoothCurve:
            if let incoming = incomingHandle, let outgoing = outgoingHandle {
                let avgLength = (points[index].point.distance(to: incoming) + points[index].point.distance(to: outgoing)) / 2.0
                let direction = points[index].point.angle(to: outgoing)
                points[index].incomingHandle = VectorPoint(
                    points[index].point.x - cos(direction) * avgLength,
                    points[index].point.y - sin(direction) * avgLength
                )
                points[index].outgoingHandle = VectorPoint(
                    points[index].point.x + cos(direction) * avgLength,
                    points[index].point.y + sin(direction) * avgLength
                )
            }
        case .smoothCorner:
            points[index].incomingHandle = incomingHandle
            points[index].outgoingHandle = outgoingHandle
        case .connector:
            points[index].incomingHandle = incomingHandle
            points[index].outgoingHandle = outgoingHandle
        default:
            break
        }
    }

    private mutating func regenerateContinuityConstraints() {
        continuityConstraints.removeAll()
        for i in 0..<max(0, points.count - 1) {
            continuityConstraints.append(ContinuityConstraint(
                pointIndex: i,
                continuityType: .g1
            ))
        }
        if isClosed && points.count > 2 {
            continuityConstraints.append(ContinuityConstraint(
                pointIndex: points.count - 1,
                continuityType: .g1
            ))
        }
    }

    private mutating func enforceLocalContinuity(at index: Int) {
        guard index >= 0 && index < points.count else { return }
        let relevantConstraints = continuityConstraints.filter { constraint in
            constraint.pointIndex == index || constraint.pointIndex == index - 1
        }
        for constraint in relevantConstraints where constraint.isLocked {
            enforceContinuityConstraint(constraint)
        }
    }

    private mutating func enforceContinuityConstraint(_ constraint: ContinuityConstraint) {
        let index = constraint.pointIndex
        guard index >= 0 && index < points.count - 1 else { return }
        let currentPoint = points[index]
        let nextPoint = points[index + 1]
        switch constraint.continuityType {
        case .g1:
            if let outgoing = currentPoint.outgoingHandle,

               let incoming = nextPoint.incomingHandle {
                let direction = currentPoint.point.angle(to: outgoing)
                let incomingLength = nextPoint.point.distance(to: incoming)
                points[index + 1].incomingHandle = VectorPoint(
                    nextPoint.point.x - cos(direction) * incomingLength,
                    nextPoint.point.y - sin(direction) * incomingLength
                )
            }
        case .c1:
            if let outgoing = currentPoint.outgoingHandle {
                let direction = currentPoint.point.angle(to: outgoing)
                let outgoingLength = currentPoint.point.distance(to: outgoing)
                points[index + 1].incomingHandle = VectorPoint(
                    nextPoint.point.x - cos(direction) * outgoingLength,
                    nextPoint.point.y - sin(direction) * outgoingLength
                )
            }
        default:
            break
        }
    }

    private mutating func enforceClosingContinuity() {
        guard isClosed && points.count > 2 else { return }
        let lastIndex = points.count - 1
        let firstPoint = points[0]
        let lastPoint = points[lastIndex]
        if let lastOutgoing = lastPoint.outgoingHandle,

           let firstIncoming = firstPoint.incomingHandle {
            let direction = lastPoint.point.angle(to: lastOutgoing)
            let incomingLength = firstPoint.point.distance(to: firstIncoming)
            points[0].incomingHandle = VectorPoint(
                firstPoint.point.x - cos(direction) * incomingLength,
                firstPoint.point.y - sin(direction) * incomingLength
            )
        }
    }

    func toLegacyVectorPath() -> VectorPath {
        guard !points.isEmpty else {
            return VectorPath(elements: [], isClosed: isClosed)
        }
        var elements: [PathElement] = []
        elements.append(.move(to: points[0].point))
        for i in 1..<points.count {
            let currentPoint = points[i]
            let previousPoint = points[i - 1]
            if let prevOutgoing = previousPoint.outgoingHandle,

               let currIncoming = currentPoint.incomingHandle {
                elements.append(.curve(
                    to: currentPoint.point,
                    control1: prevOutgoing,
                    control2: currIncoming
                ))
            } else {
                elements.append(.line(to: currentPoint.point))
            }
        }
        if isClosed,
           let lastPoint = points.last,

           let firstPoint = points.first {
            if let lastOutgoing = lastPoint.outgoingHandle,

               let firstIncoming = firstPoint.incomingHandle {
                elements.append(.curve(
                    to: firstPoint.point,
                    control1: lastOutgoing,
                    control2: firstIncoming
                ))
            } else {
                elements.append(.line(to: firstPoint.point))
            }
            elements.append(.close)
        }
        return VectorPath(elements: elements, isClosed: isClosed)
    }

    static func fromLegacyVectorPath(_ legacyPath: VectorPath) -> ProfessionalVectorPath {
        var professionalPoints: [ProfessionalBezierMathematics.BezierPoint] = []
        var currentPoint: VectorPoint?
        for element in legacyPath.elements {
            switch element {
            case .move(let to):
                currentPoint = to
                professionalPoints.append(ProfessionalBezierMathematics.BezierPoint.cornerPoint(at: to))
            case .line(let to):
                professionalPoints.append(ProfessionalBezierMathematics.BezierPoint.cornerPoint(at: to))
                currentPoint = to
            case .curve(let to, let control1, let control2):
                if !professionalPoints.isEmpty {
                    professionalPoints[professionalPoints.count - 1].outgoingHandle = control1
                    professionalPoints[professionalPoints.count - 1].pointType = .smoothCurve
                    professionalPoints[professionalPoints.count - 1].handleConstraint = .symmetric
                }
                let newPoint = ProfessionalBezierMathematics.BezierPoint(
                    point: to,
                    incomingHandle: control2,
                    outgoingHandle: nil,
                    pointType: .smoothCurve,
                    handleConstraint: .symmetric
                )
                professionalPoints.append(newPoint)
                currentPoint = to
            case .quadCurve(let to, let control):
                if let current = currentPoint {
                    let control1 = VectorPoint(
                        current.x + (2.0/3.0) * (control.x - current.x),
                        current.y + (2.0/3.0) * (control.y - current.y)
                    )
                    let control2 = VectorPoint(
                        to.x + (2.0/3.0) * (control.x - to.x),
                        to.y + (2.0/3.0) * (control.y - to.y)
                    )
                    if !professionalPoints.isEmpty {
                        professionalPoints[professionalPoints.count - 1].outgoingHandle = control1
                        professionalPoints[professionalPoints.count - 1].pointType = .smoothCurve
                    }
                    let newPoint = ProfessionalBezierMathematics.BezierPoint(
                        point: to,
                        incomingHandle: control2,
                        outgoingHandle: nil,
                        pointType: .smoothCurve,
                        handleConstraint: .symmetric
                    )
                    professionalPoints.append(newPoint)
                }
                currentPoint = to
            case .close:
                break
            }
        }
        var professionalPath = ProfessionalVectorPath(
            points: professionalPoints,
            isClosed: legacyPath.isClosed
        )
        professionalPath.generateSmoothHandles()
        return professionalPath
    }

    struct PathAnalysis {
        var issues: [String] = []
        var suggestions: [String] = []
        var quality: Double = 1.0
        var continuityIssues: [ContinuityIssue] = []
    }

    struct ContinuityIssue {
    }

    func analyzePath() -> PathAnalysis {
        var analysis = PathAnalysis()
        for i in 0..<points.count - 1 {
            if let constraint = continuityConstraints.first(where: { $0.pointIndex == i }) {
                let curve1 = getSegmentPoints(at: i)
                let curve2 = getSegmentPoints(at: i + 1)
                if let c1 = curve1, let c2 = curve2 {
                    let actualContinuity = ProfessionalBezierMathematics.analyzeContinuity(
                        curve1: c1,
                        curve2: c2,
                        tolerance: constraint.tolerance
                    )
                    if actualContinuity.priority < constraint.continuityType.priority {
                        analysis.continuityIssues.append(ContinuityIssue())
                    }
                }
            }
        }
        return analysis
    }

    private func getSegmentPoints(at index: Int) -> [VectorPoint]? {
        guard index >= 0 && index < points.count - 1 else { return nil }
        let p0 = points[index].point
        let p3 = points[index + 1].point
        let p1 = points[index].outgoingHandle ?? p0
        let p2 = points[index + 1].incomingHandle ?? p3
        return [p0, p1, p2, p3]
    }
}

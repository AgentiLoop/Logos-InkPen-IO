import SwiftUI

struct MoveObjectDialog: View {

    @ObservedObject var document: VectorDocument

    @Binding var isPresented: Bool

    @State private var xDelta: String = "0"
    @State private var yDelta: String = "0"

    @FocusState private var focusedField: Field?
    enum Field {
        case x, y
    }

    private var currentUnit: MeasurementUnit {
        document.settings.unit
    }

    private var unitSuffix: String {
        currentUnit.abbreviation
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Move")
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Horizontal:")
                        .frame(width: 80, alignment: .trailing)
                    TextField("0", text: $xDelta)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .x)
                        .onSubmit {
                            focusedField = .y
                        }
                    Text(unitSuffix)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                }
                HStack {
                    Text("Vertical:")
                        .frame(width: 80, alignment: .trailing)
                    TextField("0", text: $yDelta)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .y)
                        .onSubmit {
                            applyMove()
                        }
                    Text(unitSuffix)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                }
            }
            Text("Use positive values to move right/down, negative to move left/up")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                Button("Move") {
                    applyMove()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 280)
        .onAppear {
            focusedField = .x
        }
    }

    private func applyMove() {
        guard let xValue = Double(xDelta),

              let yValue = Double(yDelta) else {
            isPresented = false
            return
        }
        let deltaX = currentUnit.toPoints(xValue)
        let deltaY = currentUnit.toPoints(yValue)
        guard deltaX != 0 || deltaY != 0 else {
            isPresented = false
            return
        }
        if !document.viewState.selectedPoints.isEmpty {
            applyMoveToSelectedPoints(deltaX: deltaX, deltaY: deltaY)
            isPresented = false
            return
        }
        document.modifySelectedShapesWithUndo { shape in
            var transformedElements: [PathElement] = []
            for element in shape.path.elements {
                switch element {
                case .move(let to):
                    let newPt = CGPoint(x: to.x + deltaX, y: to.y + deltaY)
                    transformedElements.append(.move(to: VectorPoint(newPt)))
                case .line(let to):
                    let newPt = CGPoint(x: to.x + deltaX, y: to.y + deltaY)
                    transformedElements.append(.line(to: VectorPoint(newPt)))
                case .curve(let to, let control1, let control2):
                    let newTo = CGPoint(x: to.x + deltaX, y: to.y + deltaY)
                    let newC1 = CGPoint(x: control1.x + deltaX, y: control1.y + deltaY)
                    let newC2 = CGPoint(x: control2.x + deltaX, y: control2.y + deltaY)
                    transformedElements.append(.curve(to: VectorPoint(newTo),
                                                     control1: VectorPoint(newC1),
                                                     control2: VectorPoint(newC2)))
                case .quadCurve(let to, let control):
                    let newTo = CGPoint(x: to.x + deltaX, y: to.y + deltaY)
                    let newC = CGPoint(x: control.x + deltaX, y: control.y + deltaY)
                    transformedElements.append(.quadCurve(to: VectorPoint(newTo),
                                                         control: VectorPoint(newC)))
                case .close:
                    transformedElements.append(.close)
                }
            }
            shape.path = VectorPath(elements: transformedElements)
            shape.updateBounds()
            if shape.isGroupContainer {
                var movedGroupedShapes: [VectorShape] = []
                for var groupedShape in shape.groupedShapes {
                    var groupedElements: [PathElement] = []
                    for element in groupedShape.path.elements {
                        switch element {
                        case .move(let to):
                            let newPt = CGPoint(x: to.x + deltaX, y: to.y + deltaY)
                            groupedElements.append(.move(to: VectorPoint(newPt)))
                        case .line(let to):
                            let newPt = CGPoint(x: to.x + deltaX, y: to.y + deltaY)
                            groupedElements.append(.line(to: VectorPoint(newPt)))
                        case .curve(let to, let control1, let control2):
                            let newTo = CGPoint(x: to.x + deltaX, y: to.y + deltaY)
                            let newC1 = CGPoint(x: control1.x + deltaX, y: control1.y + deltaY)
                            let newC2 = CGPoint(x: control2.x + deltaX, y: control2.y + deltaY)
                            groupedElements.append(.curve(to: VectorPoint(newTo),
                                                         control1: VectorPoint(newC1),
                                                         control2: VectorPoint(newC2)))
                        case .quadCurve(let to, let control):
                            let newTo = CGPoint(x: to.x + deltaX, y: to.y + deltaY)
                            let newC = CGPoint(x: control.x + deltaX, y: control.y + deltaY)
                            groupedElements.append(.quadCurve(to: VectorPoint(newTo),
                                                             control: VectorPoint(newC)))
                        case .close:
                            groupedElements.append(.close)
                        }
                    }
                    groupedShape.path = VectorPath(elements: groupedElements)
                    groupedShape.updateBounds()
                    movedGroupedShapes.append(groupedShape)
                }
                shape.groupedShapes = movedGroupedShapes
            }
            if shape.typography != nil {
                if let textPos = shape.textPosition {
                    shape.textPosition = CGPoint(x: textPos.x + deltaX, y: textPos.y + deltaY)
                }
                shape.transform = CGAffineTransform(translationX: shape.transform.tx + deltaX,
                                                    y: shape.transform.ty + deltaY)
            }
        }
        isPresented = false
    }

    private func applyMoveToSelectedPoints(deltaX: CGFloat, deltaY: CGFloat) {
        let nudgeAmount = CGVector(dx: deltaX, dy: deltaY)

        var pointsByShape: [UUID: [PointID]] = [:]
        for pointID in document.viewState.selectedPoints {
            pointsByShape[pointID.shapeID, default: []].append(pointID)
        }
        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []
        for shapeID in pointsByShape.keys {
            if let shape = document.findShape(by: shapeID) {
                oldShapes[shapeID] = shape
                objectIDs.append(shapeID)
            }
        }
        for (shapeID, pointIDs) in pointsByShape {
            guard var shape = document.findShape(by: shapeID) else { continue }
            var elements = shape.path.elements
            for pointID in pointIDs {
                guard pointID.elementIndex < elements.count else { continue }
                let element = elements[pointID.elementIndex]
                switch element {
                case .move(let to):
                    elements[pointID.elementIndex] = .move(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy))
                case .line(let to):
                    elements[pointID.elementIndex] = .line(to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy))
                case .curve(let to, let c1, let c2):
                    elements[pointID.elementIndex] = .curve(
                        to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                        control1: VectorPoint(c1.x + nudgeAmount.dx, c1.y + nudgeAmount.dy),
                        control2: VectorPoint(c2.x + nudgeAmount.dx, c2.y + nudgeAmount.dy)
                    )
                case .quadCurve(let to, let c):
                    elements[pointID.elementIndex] = .quadCurve(
                        to: VectorPoint(to.x + nudgeAmount.dx, to.y + nudgeAmount.dy),
                        control: VectorPoint(c.x + nudgeAmount.dx, c.y + nudgeAmount.dy)
                    )
                case .close:
                    break
                }
            }
            shape.path = VectorPath(elements: elements, isClosed: shape.path.isClosed)
            shape.updateBounds()
            document.updateShapeByID(shapeID, silent: false) { s in
                s = shape
            }
        }
        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = document.findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }
        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.executeCommand(command)
        }
        document.viewState.objectPositionUpdateTrigger.toggle()
    }
}

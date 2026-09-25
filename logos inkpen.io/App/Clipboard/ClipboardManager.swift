import SwiftUI

class ClipboardManager {
    static let shared = ClipboardManager()

    private let pasteboard = NSPasteboard.general
    private let vectorObjectsType = NSPasteboard.PasteboardType("io.logos.logos-inkpen-io.vectorObjects")

    private init() {}

    private func regenerateUUIDsForShapes(_ shapes: [VectorShape]) -> ([VectorShape], [UUID: UUID]) {
        var oldToNewID: [UUID: UUID] = [:]
        for shape in shapes {
            oldToNewID[shape.id] = UUID()
        }
        var newShapes: [VectorShape] = []
        for shape in shapes {
            var newShape = shape
            newShape.id = oldToNewID[shape.id] ?? UUID()
            if !newShape.memberIDs.isEmpty {
                newShape.memberIDs = newShape.memberIDs.map { oldToNewID[$0] ?? $0 }
            }
            if !newShape.groupedShapes.isEmpty {
                newShape.groupedShapes = newShape.groupedShapes.map { childShape in
                    var newChild = childShape
                    newChild.id = UUID()
                    return newChild
                }
            }
            newShapes.append(newShape)
        }
        return (newShapes, oldToNewID)
    }

    private func regenerateUUIDs(for shape: VectorShape) -> VectorShape {
        var newShape = shape
        newShape.id = UUID()
        if !newShape.groupedShapes.isEmpty {
            newShape.groupedShapes = newShape.groupedShapes.map { childShape in
                regenerateUUIDs(for: childShape)
            }
        }
        return newShape
    }

    func canPaste() -> Bool {
        return pasteboard.data(forType: vectorObjectsType) != nil
    }

    func cut(from document: VectorDocument) {
        copy(from: document)
        document.removeSelectedObjects()
    }

    private func collectShapeAndMembers(
        _ shape: VectorShape,
        from document: VectorDocument,
        into out: inout [VectorShape],
        visited: inout Set<UUID>
    ) {
        guard !visited.contains(shape.id) else { return }
        visited.insert(shape.id)
        out.append(shape)
        for memberID in shape.memberIDs {
            if let memberObj = document.snapshot.objects[memberID] {
                collectShapeAndMembers(memberObj.shape, from: document, into: &out, visited: &visited)
            }
        }
    }

    func copy(from document: VectorDocument) {
        var shapesToCopy: [VectorShape] = []
        var copiedShapeIDs: Set<UUID> = []
        var textToCopy: [VectorText] = []
        for objectID in document.viewState.selectedObjectIDs {
            if let vectorObject = document.findObject(by: objectID) {
                switch vectorObject.objectType {
                case .text(let shape):
                    if let textContent = shape.textContent {
                        let originalText = document.findText(by: objectID)
                        let originalAreaSize = originalText?.areaSize ?? shape.areaSize
                        let typography = originalText?.typography ?? shape.typography ?? TypographyProperties(strokeColor: .black, fillColor: .black)
                        let position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                        let vectorText = VectorText(
                            content: textContent,
                            typography: typography,
                            position: position,
                            transform: .identity,
                            isVisible: shape.isVisible,
                            isLocked: shape.isLocked,
                            isEditing: false,
                                layerIndex: vectorObject.layerIndex,
                                cursorPosition: 0,
                                areaSize: originalAreaSize
                            )
                            textToCopy.append(vectorText)
                        }
                case .shape(let shape),
                     .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape),
                     .guide(let shape):
                    collectShapeAndMembers(shape, from: document, into: &shapesToCopy, visited: &copiedShapeIDs)
                }
            }
        }
        let clipboardData = ClipboardData(shapes: shapesToCopy, texts: textToCopy)
        do {
            let data = try JSONEncoder().encode(clipboardData)
            pasteboard.clearContents()
            pasteboard.setData(data, forType: vectorObjectsType)
        } catch {
            Log.error("❌ Failed to copy objects: \(error)", category: .error)
        }
    }

    func paste(to document: VectorDocument) {
        guard let data = pasteboard.data(forType: vectorObjectsType) else { return }
        do {
            let clipboardData = try JSONDecoder().decode(ClipboardData.self, from: data)
            guard let selectedLayerId = document.settings.selectedLayerId,
                  let layerIndex = document.snapshot.layers.firstIndex(where: { $0.id == selectedLayerId }) else { return }
            if layerIndex < document.snapshot.layers.count && document.snapshot.layers[layerIndex].isLocked {
                Log.error("❌ Cannot paste into locked layer '\(document.snapshot.layers[layerIndex].name)'", category: .error)
                return
            }
            if layerIndex < document.snapshot.layers.count {
                let layerName = document.snapshot.layers[layerIndex].name
                if layerName == "Canvas" || layerName == "Pasteboard" || layerName == "Guides" {
                    Log.error("❌ Cannot paste into system layer '\(layerName)'", category: .error)
                    return
                }
            }
            var newObjectIDs: Set<UUID> = []
            let (newShapes, _) = regenerateUUIDsForShapes(clipboardData.shapes)
            var memberIDSet = Set<UUID>()
            for shape in newShapes {
                if !shape.memberIDs.isEmpty {
                    memberIDSet.formUnion(shape.memberIDs)
                }
            }
            var topLevelObjects: [VectorObject] = []
            var memberObjects: [VectorObject] = []
            for shape in newShapes {
                let obj = VectorObject(shape: shape, layerIndex: layerIndex)
                if memberIDSet.contains(shape.id) {
                    memberObjects.append(obj)
                } else {
                    topLevelObjects.append(obj)
                    newObjectIDs.insert(shape.id)
                }
            }
            let textObjects = clipboardData.texts.map { text -> VectorObject in
                var newText = text
                newText.id = UUID()
                newText.layerIndex = layerIndex
                let textShape = VectorShape.from(newText)
                newObjectIDs.insert(newText.id)
                return VectorObject(shape: textShape, layerIndex: layerIndex)
            }
            for memberObj in memberObjects {
                document.snapshot.objects[memberObj.id] = memberObj
            }
            let objectsToAdd = topLevelObjects + textObjects
            if !objectsToAdd.isEmpty {
                let currentTool = document.viewState.currentTool
                let command = AddObjectCommand(objects: objectsToAdd)
                document.commandManager.execute(command)
                if currentTool != .selection && currentTool != .directSelection {
                    document.viewState.currentTool = .selection
                }
                document.viewState.selectedObjectIDs = newObjectIDs
            }
        } catch {
            Log.error("❌ Failed to paste objects: \(error)", category: .error)
        }
    }

    func pasteInBack(to document: VectorDocument) {
        guard let data = pasteboard.data(forType: vectorObjectsType) else { return }
        do {
            let clipboardData = try JSONDecoder().decode(ClipboardData.self, from: data)
            guard let selectedLayerId = document.settings.selectedLayerId,
                  let layerIndex = document.snapshot.layers.firstIndex(where: { $0.id == selectedLayerId }) else { return }
            if layerIndex < document.snapshot.layers.count && document.snapshot.layers[layerIndex].isLocked {
                Log.error("❌ Cannot paste into locked layer '\(document.snapshot.layers[layerIndex].name)'", category: .error)
                return
            }
            if layerIndex < document.snapshot.layers.count {
                let layerName = document.snapshot.layers[layerIndex].name
                if layerName == "Canvas" || layerName == "Pasteboard" || layerName == "Guides" {
                    Log.error("❌ Cannot paste into system layer '\(layerName)'", category: .error)
                    return
                }
            }
            var newObjectIDs: Set<UUID> = []
            let (newShapes, _) = regenerateUUIDsForShapes(clipboardData.shapes)
            var memberIDSet = Set<UUID>()
            for shape in newShapes {
                if !shape.memberIDs.isEmpty {
                    memberIDSet.formUnion(shape.memberIDs)
                }
            }
            var topLevelObjects: [VectorObject] = []
            var memberObjects: [VectorObject] = []
            for shape in newShapes {
                let obj = VectorObject(shape: shape, layerIndex: layerIndex)
                if memberIDSet.contains(shape.id) {
                    memberObjects.append(obj)
                } else {
                    topLevelObjects.append(obj)
                    newObjectIDs.insert(shape.id)
                }
            }
            let textObjects = clipboardData.texts.map { text -> VectorObject in
                var newText = text
                newText.id = UUID()
                newText.layerIndex = layerIndex
                let textShape = VectorShape.from(newText)
                newObjectIDs.insert(newText.id)
                return VectorObject(shape: textShape, layerIndex: layerIndex)
            }
            for memberObj in memberObjects {
                document.snapshot.objects[memberObj.id] = memberObj
            }
            let objectsToAdd = topLevelObjects + textObjects
            if !objectsToAdd.isEmpty {
                let currentTool = document.viewState.currentTool
                let position: AddObjectAtPositionCommand.InsertPosition
                if !document.viewState.selectedObjectIDs.isEmpty {
                    position = .beforeSelection(document.viewState.selectedObjectIDs)
                } else {
                    position = .back
                }
                let command = AddObjectAtPositionCommand(objects: objectsToAdd, position: position)
                document.commandManager.execute(command)
                if currentTool != .selection && currentTool != .directSelection {
                    document.viewState.currentTool = .selection
                }
                document.viewState.selectedObjectIDs = newObjectIDs
            }
        } catch {
            Log.error("❌ Failed to paste in back: \(error)", category: .error)
        }
    }

    func pasteInFront(to document: VectorDocument) {
        guard let data = pasteboard.data(forType: vectorObjectsType) else { return }
        do {
            let clipboardData = try JSONDecoder().decode(ClipboardData.self, from: data)
            guard let selectedLayerId = document.settings.selectedLayerId,
                  let layerIndex = document.snapshot.layers.firstIndex(where: { $0.id == selectedLayerId }) else { return }
            if layerIndex < document.snapshot.layers.count && document.snapshot.layers[layerIndex].isLocked {
                Log.error("❌ Cannot paste into locked layer '\(document.snapshot.layers[layerIndex].name)'", category: .error)
                return
            }
            if layerIndex < document.snapshot.layers.count {
                let layerName = document.snapshot.layers[layerIndex].name
                if layerName == "Canvas" || layerName == "Pasteboard" || layerName == "Guides" {
                    Log.error("❌ Cannot paste into system layer '\(layerName)'", category: .error)
                    return
                }
            }
            var newObjectIDs: Set<UUID> = []
            let (newShapes, _) = regenerateUUIDsForShapes(clipboardData.shapes)
            var memberIDSet = Set<UUID>()
            for shape in newShapes {
                if !shape.memberIDs.isEmpty {
                    memberIDSet.formUnion(shape.memberIDs)
                }
            }
            var topLevelObjects: [VectorObject] = []
            var memberObjects: [VectorObject] = []
            for shape in newShapes {
                let obj = VectorObject(shape: shape, layerIndex: layerIndex)
                if memberIDSet.contains(shape.id) {
                    memberObjects.append(obj)
                } else {
                    topLevelObjects.append(obj)
                    newObjectIDs.insert(shape.id)
                }
            }
            let textObjects = clipboardData.texts.map { text -> VectorObject in
                var newText = text
                newText.id = UUID()
                newText.layerIndex = layerIndex
                let textShape = VectorShape.from(newText)
                newObjectIDs.insert(newText.id)
                return VectorObject(shape: textShape, layerIndex: layerIndex)
            }
            for memberObj in memberObjects {
                document.snapshot.objects[memberObj.id] = memberObj
            }
            let objectsToAdd = topLevelObjects + textObjects
            if !objectsToAdd.isEmpty {
                let currentTool = document.viewState.currentTool
                let position: AddObjectAtPositionCommand.InsertPosition
                if !document.viewState.selectedObjectIDs.isEmpty {
                    position = .afterSelection(document.viewState.selectedObjectIDs)
                } else {
                    position = .front
                }
                let command = AddObjectAtPositionCommand(objects: objectsToAdd, position: position)
                document.commandManager.execute(command)
                if currentTool != .selection && currentTool != .directSelection {
                    document.viewState.currentTool = .selection
                }
                document.viewState.selectedObjectIDs = newObjectIDs
            }
        } catch {
            Log.error("❌ Failed to paste in front: \(error)", category: .error)
        }
    }
}

struct ClipboardData: Codable {
    let shapes: [VectorShape]
    let texts: [VectorText]
}

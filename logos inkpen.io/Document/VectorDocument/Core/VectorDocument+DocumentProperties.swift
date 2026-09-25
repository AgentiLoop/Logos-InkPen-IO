import SwiftUI

extension VectorDocument {

    var documentUnits: VectorUnit {
        get {
            switch settings.unit {
            case .inches: return .inches
            case .centimeters: return .millimeters
            case .millimeters: return .millimeters
            case .points: return .points
            case .pixels: return .points
            case .picas: return .points
            }
        }
    }

    func getDocumentBounds() -> CGRect {
        var documentBounds = CGRect.zero
        var hasContent = false
        for layer in snapshot.layers {
            guard layer.isVisible else { continue }
            let layerIndex = snapshot.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = getShapesForLayer(layerIndex)
            for shape in shapesInLayer {
                guard shape.isVisible else { continue }
                let shapeBounds = shape.bounds
                if !hasContent {
                    documentBounds = shapeBounds
                    hasContent = true
                } else {
                    documentBounds = documentBounds.union(shapeBounds)
                }
            }
        }
        for obj in snapshot.objects.values {
            guard case .text(let shape) = obj.objectType,
                  var textObj = VectorText.from(shape) else { continue }
            textObj.layerIndex = obj.layerIndex
            guard textObj.isVisible else { continue }
            let textBounds = textObj.bounds
            if !hasContent {
                documentBounds = textBounds
                hasContent = true
            } else {
                documentBounds = documentBounds.union(textBounds)
            }
        }
        if !hasContent {
            documentBounds = CGRect(origin: .zero, size: settings.sizeInPoints)
        }
        return documentBounds
    }

    func getArtworkBounds() -> CGRect? {
        var artworkBounds: CGRect = .zero
        var hasContent = false
        for (layerIndex, layer) in snapshot.layers.enumerated() where layerIndex >= 2 {
            guard layer.isVisible else { continue }
            let shapesInLayer = getShapesForLayer(layerIndex)
            for shape in shapesInLayer where shape.isVisible {
                let shapeBounds: CGRect
                if shape.isGroupContainer && !shape.memberIDs.isEmpty {
                    shapeBounds = calculateGroupBoundsFromMembers(memberIDs: shape.memberIDs)
                    Log.info("📐 Group bounds for \(shape.id): \(shapeBounds), memberIDs: \(shape.memberIDs.count)", category: .general)
                } else {
                    shapeBounds = shape.bounds.applying(shape.transform)
                }
                Log.info("📐 Shape '\(shape.name)' bounds: \(shapeBounds)", category: .general)
                if !shapeBounds.isNull && !shapeBounds.isInfinite && shapeBounds.width > 0 && shapeBounds.height > 0 {
                    if !hasContent {
                        artworkBounds = shapeBounds
                        hasContent = true
                    } else {
                        artworkBounds = artworkBounds.union(shapeBounds)
                    }
                } else {
                    Log.error("❌ Invalid bounds for '\(shape.name)': isNull=\(shapeBounds.isNull), isInfinite=\(shapeBounds.isInfinite), width=\(shapeBounds.width), height=\(shapeBounds.height)", category: .error)
                }
            }
        }
        for obj in snapshot.objects.values {
            guard case .text(let shape) = obj.objectType,
                  var textObj = VectorText.from(shape),
                  textObj.isVisible else { continue }
            textObj.layerIndex = obj.layerIndex
            if let li = textObj.layerIndex, li >= 2 {
                let textBounds = CGRect(
                    x: textObj.position.x + textObj.bounds.minX,
                    y: textObj.position.y + textObj.bounds.minY,
                    width: textObj.bounds.width,
                    height: textObj.bounds.height
                ).applying(textObj.transform)
                if !hasContent {
                    artworkBounds = textBounds
                    hasContent = true
                } else {
                    artworkBounds = artworkBounds.union(textBounds)
                }
            }
        }
        return hasContent ? artworkBounds : nil
    }

    private func calculateGroupBoundsFromMembers(memberIDs: [UUID]) -> CGRect {
        var groupBounds: CGRect = .null
        for memberID in memberIDs {
            guard let memberObject = snapshot.objects[memberID] else { continue }
            let memberShape = memberObject.shape
            let memberBounds: CGRect
            if memberShape.isGroupContainer && !memberShape.memberIDs.isEmpty {
                memberBounds = calculateGroupBoundsFromMembers(memberIDs: memberShape.memberIDs)
            } else if memberShape.typography != nil, let textPosition = memberShape.textPosition, let areaSize = memberShape.areaSize {
                memberBounds = CGRect(origin: textPosition, size: areaSize)
            } else {
                memberBounds = memberShape.bounds.applying(memberShape.transform)
            }
            if !memberBounds.isNull && !memberBounds.isInfinite {
                groupBounds = groupBounds.union(memberBounds)
            }
        }
        return groupBounds
    }
}

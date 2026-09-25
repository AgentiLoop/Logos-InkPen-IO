import SwiftUI
import Combine

extension VectorDocument {

    func updateTextFontFamilyPreview(id: UUID, fontFamily: String) {
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.fontFamily = fontFamily
            textPreviewTypography[id] = previewTypography
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateTextFontVariantPreview(id: UUID, fontVariant: String) {
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.fontVariant = fontVariant
            textPreviewTypography[id] = previewTypography
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateTextFontFamilyDirect(id: UUID, fontFamily: String) {
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.fontFamily = fontFamily
            textPreviewTypography[id] = previewTypography
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateTextFontVariantDirect(id: UUID, fontVariant: String) {
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.fontVariant = fontVariant
            textPreviewTypography[id] = previewTypography
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateTextFontSizePreview(id: UUID, fontSize: CGFloat) {
        if let textObject = findText(by: id) {
            var previewTypography = textObject.typography

            let oldFontSize = previewTypography.fontSize
            let lineHeightRatio = previewTypography.lineHeight / oldFontSize
            previewTypography.fontSize = fontSize
            previewTypography.lineHeight = fontSize * lineHeightRatio
            textPreviewTypography[id] = previewTypography
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateTextLineSpacingPreview(id: UUID, lineSpacing: Double) {
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.lineSpacing = lineSpacing
            textPreviewTypography[id] = previewTypography
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateTextLineHeightPreview(id: UUID, lineHeight: Double) {
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.lineHeight = lineHeight
            textPreviewTypography[id] = previewTypography
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateTextFontSizePreviewDirect(id: UUID, typography: TypographyProperties) {
        textPreviewTypography[id] = typography
        NotificationCenter.default.post(
            name: Notification.Name("TextPreviewUpdate"),
            object: nil,
            userInfo: ["textID": id, "typography": typography]
        )
    }

    func updateTextLineSpacingPreviewDirect(id: UUID, typography: TypographyProperties) {
        textPreviewTypography[id] = typography
        NotificationCenter.default.post(
            name: Notification.Name("TextPreviewUpdate"),
            object: nil,
            userInfo: ["textID": id, "typography": typography]
        )
    }

    func updateTextLineHeightPreviewDirect(id: UUID, typography: TypographyProperties) {
        textPreviewTypography[id] = typography
        NotificationCenter.default.post(
            name: Notification.Name("TextPreviewUpdate"),
            object: nil,
            userInfo: ["textID": id, "typography": typography]
        )
    }

    func clearTextPreviewTypography(id: UUID) {
        textPreviewTypography.removeValue(forKey: id)
    }

    func updateTextFillOpacityPreview(id: UUID, opacity: Double) {
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.fillOpacity = opacity
            textPreviewTypography[id] = previewTypography
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateShapeFillOpacityPreview(id: UUID, opacity: Double) {
        NotificationCenter.default.post(
            name: Notification.Name("ShapePreviewUpdate"),
            object: nil,
            userInfo: ["shapeID": id, "fillOpacity": opacity]
        )
    }

    func updateShapeStrokeOpacityPreview(id: UUID, opacity: Double) {
        NotificationCenter.default.post(
            name: Notification.Name("ShapePreviewUpdate"),
            object: nil,
            userInfo: ["shapeID": id, "strokeOpacity": opacity]
        )
    }

    func updateShapeStrokeWidthPreview(id: UUID, width: Double) {
        NotificationCenter.default.post(
            name: Notification.Name("ShapePreviewUpdate"),
            object: nil,
            userInfo: ["shapeID": id, "strokeWidth": width]
        )
    }

    func updateShapeStrokePlacementPreview(id: UUID, placement: StrokePlacement) {
        NotificationCenter.default.post(
            name: Notification.Name("ShapePreviewUpdate"),
            object: nil,
            userInfo: ["shapeID": id, "strokePlacement": placement.rawValue]
        )
    }

    func updateTextFillColorInUnified(id: UUID, color: VectorColor) {
        updateShapeByID(id) { shape in
            if shape.typography != nil {
                shape.typography?.fillColor = color
                shape.typography?.fillOpacity = defaultFillOpacity
            } else if let textObject = findText(by: id) {
                shape.typography = textObject.typography
                shape.typography?.fillColor = color
                shape.typography?.fillOpacity = defaultFillOpacity
            }
        }
    }

    func updateTextTypographyInUnified(id: UUID, typography: TypographyProperties) {
        updateShapeByID(id) { shape in
            shape.typography = typography
        }
    }

    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {
        updateShapeByID(id) { shape in
            if shape.typography != nil {
                shape.typography?.hasStroke = true
                shape.typography?.strokeColor = color
            } else if let textObject = findText(by: id) {
                shape.typography = textObject.typography
                shape.typography?.hasStroke = true
                shape.typography?.strokeColor = color
            }
        }
    }
}

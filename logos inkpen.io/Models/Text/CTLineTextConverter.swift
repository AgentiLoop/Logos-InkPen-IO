import Foundation
import CoreText
import AppKit

struct CTLineTextConverter {

    static func convertTextToPaths(
        text: String,
        font: PlatformFont,
        textBoxFrame: CGRect,
        alignment: NSTextAlignment,
        lineSpacing: CGFloat,
        lineHeight: CGFloat,
        letterSpacing: CGFloat
    ) -> [CGPath] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineSpacing = max(0, lineSpacing)
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        if letterSpacing != 0 {
            attributes[.kern] = letterSpacing
        }
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: CGSize(width: textBoxFrame.width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)
        let textRange = NSRange(location: 0, length: text.count)
        layoutManager.ensureGlyphs(forGlyphRange: textRange)
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(for: textContainer)

        var linePaths: [CGPath] = []
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, lineUsedRect, _, lineRange, _ in
            let lineString = (text as NSString).substring(with: lineRange)
            let lineAttribString = NSAttributedString(string: lineString, attributes: attributes)

            var line = CTLineCreateWithAttributedString(lineAttribString)
            if alignment == .justified,

               let justifiedLine = CTLineCreateJustifiedLine(line, 1.0, lineUsedRect.width) {
                line = justifiedLine
            }
            let glyphLocation = layoutManager.location(forGlyphAt: lineRange.location)
            let lineX: CGFloat
            switch alignment {
            case .left, .justified:
                lineX = textBoxFrame.origin.x + lineUsedRect.origin.x + glyphLocation.x
            case .center, .right:
                lineX = textBoxFrame.origin.x + lineRect.origin.x + glyphLocation.x
            default:
                lineX = textBoxFrame.origin.x + lineUsedRect.origin.x + glyphLocation.x
            }
            let lineY = textBoxFrame.origin.y + lineRect.origin.y + glyphLocation.y
            if let linePath = convertCTLineToPath(line: line, position: CGPoint(x: lineX, y: lineY)) {
                linePaths.append(linePath)
            }
        }
        return linePaths
    }

    private static func convertCTLineToPath(line: CTLine, position: CGPoint) -> CGPath? {
        let linePath = CGMutablePath()
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun], !runs.isEmpty else { return nil }
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            guard glyphCount > 0 else { continue }
            guard let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any] else { continue }
            guard let font = attributes[.font] as? PlatformFont else { continue }
            let ctFont = font as CTFont

            var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
            var positions = [CGPoint](repeating: .zero, count: glyphCount)
            CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
            for i in 0..<glyphCount {
                let glyph = glyphs[i]
                let glyphPosition = positions[i]
                if let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) {
                    if isRectangleGlyph(glyphPath) {
                        continue
                    }
                    var transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
                    transform = transform.translatedBy(
                        x: position.x + glyphPosition.x,
                        y: -(position.y + glyphPosition.y)
                    )
                    linePath.addPath(glyphPath, transform: transform)
                }
            }
        }
        return linePath.isEmpty ? nil : linePath
    }

    private static func isRectangleGlyph(_ path: CGPath) -> Bool {
        var pointCount = 0
        var hasOnlyLines = true
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                pointCount += 1
            case .addQuadCurveToPoint, .addCurveToPoint:
                hasOnlyLines = false
            case .closeSubpath:
                break

            @unknown default:
                break
            }
        }
        return hasOnlyLines && pointCount == 5
    }
}

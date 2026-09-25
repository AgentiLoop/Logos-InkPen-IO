import AppKit

class DisabledContextMenuTextView: NSTextView {
    var allowsInteraction: Bool = true
    var shouldShowCursor: Bool = true

    override var insertionPointColor: PlatformColor? {
        didSet {
            if let layoutManager = layoutManager,

               let textContainer = textContainer {
                let glyphRange = layoutManager.glyphRange(for: textContainer)
                if glyphRange.length > 0 {
                    let charIndex = selectedRange().location
                    if charIndex < layoutManager.numberOfGlyphs {
                        let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: charIndex, length: 0), in: textContainer)
                        setNeedsDisplay(rect, avoidAdditionalLayout: true)
                    }
                }
            }
        }
    }

    override var wantsDefaultClipping: Bool {
        return false
    }

    override func draw(_ dirtyRect: CGRect) {
        let extendedRect = dirtyRect.insetBy(dx: -10, dy: -10)
        super.draw(extendedRect)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }

    override func rightMouseDown(with event: NSEvent) {
    }

    override func mouseDown(with event: NSEvent) {
        if allowsInteraction {
            super.mouseDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        if allowsInteraction {
            return super.becomeFirstResponder()
        }
        return false
    }

    override func drawInsertionPoint(in rect: CGRect, color: PlatformColor, turnedOn flag: Bool) {
        let cursorColor = shouldShowCursor ? color : PlatformColor.clear

        var thickerRect = rect
        thickerRect.size.width = 1.0
        super.drawInsertionPoint(in: thickerRect, color: cursorColor, turnedOn: flag)
    }
}

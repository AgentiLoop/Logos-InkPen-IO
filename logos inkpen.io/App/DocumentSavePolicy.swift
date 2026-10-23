import AppKit
import ObjectiveC

/// Edits are only written to disk when the user saves.
///
/// SwiftUI's DocumentGroup document class autosaves in place: every edit was
/// silently written back over the opened file (an opened SVG was replaced by our
/// SVG export), so a bad edit could not be recovered by closing without saving.
/// With autosave-in-place off, AppKit shows the edited dot, asks
/// "Save changes?" on close/quit, and never writes the file on its own.
enum DocumentSavePolicy {

    private static var patchedClasses = Set<ObjectIdentifier>()

    /// Makes `autosavesInPlace` return false for the document's runtime class
    /// and every superclass below NSDocument (covers KVO subclasses).
    static func disableAutosaveInPlace(for document: NSDocument) {
        let selector = #selector(getter: NSDocument.autosavesInPlace)
        guard let baseMethod = class_getClassMethod(NSDocument.self, selector) else { return }
        let types = method_getTypeEncoding(baseMethod)
        let block: @convention(block) (AnyObject) -> Bool = { _ in false }
        let imp = imp_implementationWithBlock(block)

        var current: AnyClass? = object_getClass(document)
        while let cls = current, cls != NSDocument.self {
            if patchedClasses.insert(ObjectIdentifier(cls)).inserted, let meta = object_getClass(cls) {
                class_replaceMethod(meta, selector, imp, types)
            }
            current = class_getSuperclass(cls)
        }
    }
}

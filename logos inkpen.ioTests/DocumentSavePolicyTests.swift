import XCTest
import AppKit
import ObjectiveC
@testable import logos_inkpen_io

/// Regression: edits were autosaved in place over the opened file, so a
/// corrupted edit could never be discarded by closing without saving.
final class DocumentSavePolicyTests: XCTestCase {

    /// Stands in for SwiftUI's DocumentGroup document class, which autosaves in place.
    private final class AutosavingDocument: NSDocument {
        override class var autosavesInPlace: Bool { true }
    }

    private final class OtherDocument: NSDocument {
        override class var autosavesInPlace: Bool { true }
    }

    /// Asks the way AppKit does (Objective-C message send), not via Swift static dispatch.
    private func autosavesInPlace(_ cls: AnyClass) -> Bool {
        let selector = #selector(getter: NSDocument.autosavesInPlace)
        typealias Getter = @convention(c) (AnyClass, Selector) -> Bool
        guard let method = class_getClassMethod(cls, selector) else { return false }
        return unsafeBitCast(method_getImplementation(method), to: Getter.self)(cls, selector)
    }

    func testDisablesAutosaveInPlaceForDocumentClass() {
        let document = AutosavingDocument()
        XCTAssertTrue(autosavesInPlace(AutosavingDocument.self))

        DocumentSavePolicy.disableAutosaveInPlace(for: document)

        XCTAssertFalse(autosavesInPlace(AutosavingDocument.self))
    }

    func testIsIdempotentAndLeavesOtherClassesAlone() {
        let document = AutosavingDocument()
        DocumentSavePolicy.disableAutosaveInPlace(for: document)
        DocumentSavePolicy.disableAutosaveInPlace(for: document)

        XCTAssertFalse(autosavesInPlace(AutosavingDocument.self))
        XCTAssertTrue(autosavesInPlace(OtherDocument.self))
    }
}

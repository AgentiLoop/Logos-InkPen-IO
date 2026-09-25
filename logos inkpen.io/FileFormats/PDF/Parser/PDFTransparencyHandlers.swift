import SwiftUI

extension PDFCommandParser {

    func handleFillOpacity(scanner: CGPDFScannerRef) {
        var opacity: CGFloat = 1.0
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            Log.error("PDF: Failed to read fill opacity", category: .error)
            return
        }
        currentFillOpacity = Double(opacity)
    }

    func handleStrokeOpacity(scanner: CGPDFScannerRef) {
        var opacity: CGFloat = 1.0
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            Log.error("PDF: Failed to read stroke opacity", category: .error)
            return
        }
        currentStrokeOpacity = Double(opacity)
    }

    func handleGraphicsState(scanner: CGPDFScannerRef) {
        var nameRef: CGPDFStringRef?
        var namePtr: UnsafePointer<CChar>?
        var name: String
        if CGPDFScannerPopName(scanner, &namePtr), let namePtrUnwrapped = namePtr {
            name = String(cString: namePtrUnwrapped)
        } else if CGPDFScannerPopString(scanner, &nameRef) {
            guard let nameRefUnwrapped = nameRef,

                  let textString = CGPDFStringCopyTextString(nameRefUnwrapped) else {
                Log.error("PDF: Failed to copy text string from graphics state name", category: .error)
                return
            }
            name = textString as String
        } else {
            Log.error("PDF: Failed to read graphics state name (tried both name and string formats)", category: .error)
            return
        }
        guard let page = currentPage else {
            return
        }
        guard let resourceDict = page.dictionary else {
            return
        }
        var resourcesRef: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef) {
            return
        }
        guard let resourcesDict = resourcesRef else {
            return
        }
        var extGStateDict: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourcesDict, "ExtGState", &extGStateDict) {
            return
        }
        guard let extGState = extGStateDict else {
            return
        }
        var stateDict: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(extGState, name, &stateDict),

              let state = stateDict else {
            return
        }
        var fillOpacity: CGFloat = 1.0
        var strokeOpacity: CGFloat = 1.0
        if CGPDFDictionaryGetNumber(state, "ca", &fillOpacity) {
            currentFillOpacity = Double(fillOpacity)
        } else {
            currentFillOpacity = 1.0
        }
        if CGPDFDictionaryGetNumber(state, "CA", &strokeOpacity) {
            currentStrokeOpacity = Double(strokeOpacity)
        } else {
            currentStrokeOpacity = 1.0
        }
        if name == "Gs1" {
            gs1FillOpacity = currentFillOpacity
            gs1StrokeOpacity = currentStrokeOpacity
        } else if name == "Gs3" {
            gs3FillOpacity = currentFillOpacity
            gs3StrokeOpacity = currentStrokeOpacity
        }
    }

    func handleXObject(scanner: CGPDFScannerRef) {
        xObjectSavedFillOpacity = currentFillOpacity
        xObjectSavedStrokeOpacity = currentStrokeOpacity
    }

    func handleXObjectWithOpacitySaving(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            Log.error("PDF: Failed to read XObject name", category: .error)
            return
        }
        guard let namePtr else {
            Log.error("PDF: XObject name pointer was nil", category: .error)
            return
        }
        let name = String(cString: namePtr)

        var savedFillOpacity: Double
        var savedStrokeOpacity: Double
        if name == "Fm1" {
            savedFillOpacity = gs1FillOpacity
            savedStrokeOpacity = gs1StrokeOpacity
        } else if name == "Fm2" {
            savedFillOpacity = gs3FillOpacity
            savedStrokeOpacity = gs3StrokeOpacity
        } else {
            savedFillOpacity = currentFillOpacity
            savedStrokeOpacity = currentStrokeOpacity
        }
        xObjectSavedFillOpacity = savedFillOpacity
        xObjectSavedStrokeOpacity = savedStrokeOpacity
        processXObjectWithImageSupport(name: name)
    }
}

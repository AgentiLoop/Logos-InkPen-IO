import SwiftUI

extension PDFCommandParser {

    func extractGradientFromXObjectResources(shadingName: String, resourcesDict: CGPDFDictionaryRef?) -> VectorGradient? {
        guard let xObjectResourcesDict = resourcesDict else {
            Log.error("PDF: ❌ No XObject resources dictionary provided", category: .error)
            return nil
        }
        var shadingResourceDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(xObjectResourcesDict, "Shading", &shadingResourceDict),

              let shadingDict = shadingResourceDict else {
            Log.error("PDF: ❌ No Shading resources found in XObject dictionary", category: .error)
            return nil
        }
        var shadingObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, shadingName, &shadingObj),

              let shadingObject = shadingObj else {
            Log.error("PDF: ❌ Shading '\(shadingName)' not found in XObject Shading resources", category: .error)
            return nil
        }
        var pdfShadingDict: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(shadingObject, .dictionary, &pdfShadingDict),

              let shadingDictionary = pdfShadingDict else {
            Log.error("PDF: ❌ Could not extract shading dictionary for '\(shadingName)' from XObject resources", category: .error)
            return nil
        }
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDictionary)
        if !extractedStops.isEmpty {
            let gradient = parseGradientFromDictionary(shadingDictionary)
            if let linearGradient = gradient, case .linear(var linear) = linearGradient {
                linear.stops = extractedStops
                return .linear(linear)
            }
        } else {
            Log.error("PDF: ❌ FAILED to extract gradient stops from PDF stream for '\(shadingName)' from XObject", category: .error)
        }
        let gradient = parseGradientFromDictionary(shadingDictionary)
        return gradient
    }

    func extractGradientFromPageResources(shadingName: String) -> VectorGradient? {
        guard let pageResourcesDict = pageResourcesDict else {
            Log.error("PDF: ❌ No page resources dictionary available", category: .error)
            return nil
        }
        var shadingResourceDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageResourcesDict, "Shading", &shadingResourceDict),

              let shadingDict = shadingResourceDict else {
            Log.error("PDF: ❌ No Shading resources found in page dictionary", category: .error)
            return nil
        }
        var shadingObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, shadingName, &shadingObj),

              let shadingObject = shadingObj else {
            Log.error("PDF: ❌ Shading '\(shadingName)' not found in Shading resources", category: .error)
            return nil
        }
        var pdfShadingDict: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(shadingObject, .dictionary, &pdfShadingDict),

              let shadingDictionary = pdfShadingDict else {
            Log.error("PDF: ❌ Could not extract shading dictionary for '\(shadingName)'", category: .error)
            return nil
        }
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDictionary)
        if !extractedStops.isEmpty {
            let gradient = parseGradientFromDictionary(shadingDictionary)
            if let linearGradient = gradient, case .linear(var linear) = linearGradient {
                linear.stops = extractedStops
                return .linear(linear)
            }
        } else {
            Log.error("PDF: ❌ FAILED to extract gradient stops from PDF stream for '\(shadingName)'", category: .error)
        }
        let gradient = parseGradientFromDictionary(shadingDictionary)
        return gradient
    }

    func extractGradientFromShading(shadingName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let shadingCString = shadingName.cString(using: .utf8),

              let pdfShading = CGPDFContentStreamGetResource(stream, "Shading", shadingCString) else {
            Log.error("PDF: ❌ Could not find shading resource '\(shadingName)' in content stream resources", category: .error)
            return nil
        }
        var shadingDictRef: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(pdfShading, .dictionary, &shadingDictRef),

              let shadingDict = shadingDictRef else {
            Log.error("PDF: ❌ Could not extract shading dictionary for '\(shadingName)'", category: .error)
            return nil
        }
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDict)
        if !extractedStops.isEmpty {
            let gradient = parseGradientFromDictionary(shadingDict)
            if let linearGradient = gradient, case .linear(var linear) = linearGradient {
                linear.stops = extractedStops
                return .linear(linear)
            }
        } else {
            Log.error("PDF: ❌ FAILED to extract gradient stops from PDF stream for '\(shadingName)'", category: .error)
        }
        let gradient = parseGradientFromDictionary(shadingDict)
        return gradient
    }
}

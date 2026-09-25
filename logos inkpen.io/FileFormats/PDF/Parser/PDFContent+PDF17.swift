import SwiftUI
import PDFKit

extension PDFCommandParser {

    func handleXObjectPDF17(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            Log.error("\(detectedPDFVersion): Failed to read XObject name", category: .error)
            return
        }
        guard let namePtr else {
            Log.error("\(detectedPDFVersion): XObject name pointer was nil", category: .error)
            return
        }
        let name = String(cString: namePtr)
        processXObjectPDF17(name: name)
    }

    func processXObjectPDF17(name: String, parentResourcesDict: CGPDFDictionaryRef? = nil) {
        var foundXObject: CGPDFObjectRef? = nil
        var foundResourcesDict: CGPDFDictionaryRef? = nil
        if let parentResources = parentResourcesDict {
            var parentXObjectDictRef: CGPDFDictionaryRef? = nil
            if CGPDFDictionaryGetDictionary(parentResources, "XObject", &parentXObjectDictRef),

               let parentXObjectDict = parentXObjectDictRef {
                var parentXObjectRef: CGPDFObjectRef? = nil
                if CGPDFDictionaryGetObject(parentXObjectDict, name, &parentXObjectRef),

                   let parentXObject = parentXObjectRef {
                    foundXObject = parentXObject
                    foundResourcesDict = parentResources
                }
            }
        }
        if foundXObject == nil {
            guard let page = currentPage else {
                return
            }
            guard let resourceDict = page.dictionary else {
                return
            }
            var resourcesRef: CGPDFDictionaryRef? = nil
            guard CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef),

                  let resourcesDict = resourcesRef else {
                return
            }
            pageResourcesDict = resourcesDict
            var xObjectDictRef: CGPDFDictionaryRef? = nil
            guard CGPDFDictionaryGetDictionary(resourcesDict, "XObject", &xObjectDictRef),

                  let xObjectDict = xObjectDictRef else {
                return
            }
            var xObjectRef: CGPDFObjectRef? = nil
            guard CGPDFDictionaryGetObject(xObjectDict, name, &xObjectRef),

                  let xObject = xObjectRef else {
                return
            }
            foundXObject = xObject
            foundResourcesDict = resourcesDict
        }
        guard let xObject = foundXObject else {
            return
        }
        var xObjectStreamRef: CGPDFStreamRef? = nil
        guard CGPDFObjectGetValue(xObject, .stream, &xObjectStreamRef),

              let xObjectStream = xObjectStreamRef else {
            return
        }
        guard let xObjectStreamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            return
        }
        var subtypeNamePtr: UnsafePointer<CChar>? = nil
        guard CGPDFDictionaryGetName(xObjectStreamDict, "Subtype", &subtypeNamePtr),
              let subtypeName = subtypeNamePtr,
              String(cString: subtypeName) == "Form" else {
            return
        }
        var xObjectResourcesDict: CGPDFDictionaryRef? = nil
        if CGPDFDictionaryGetDictionary(xObjectStreamDict, "Resources", &xObjectResourcesDict) {
        } else {
            xObjectResourcesDict = foundResourcesDict
        }
        parseXObjectContentStream(xObjectStream, dictionary: xObjectStreamDict, name: name, resourcesDict: xObjectResourcesDict)
    }

    func parseXObjectContentStream(_ xObjectStream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef, name: String, resourcesDict: CGPDFDictionaryRef? = nil) {
        let savedFillOpacity = xObjectSavedFillOpacity
        let savedStrokeOpacity = xObjectSavedStrokeOpacity

        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(xObjectStream, &format) else {
            Log.error("\(detectedPDFVersion): XObject '\(name)' - FAILED to get stream data", category: .error)
            return
        }
        let dataLength = CFDataGetLength(data)
        if let dataPtr = CFDataGetBytePtr(data), dataLength > 0 {
            let previewLength = min(dataLength, 200)
            let previewData = Data(bytes: dataPtr, count: previewLength)
            if String(data: previewData, encoding: .ascii) != nil, dataLength < 1000 {
            }
            parseDecompressedXObjectContent(data: data, name: name,
                                          savedFillOpacity: savedFillOpacity,
                                          savedStrokeOpacity: savedStrokeOpacity,
                                          resourcesDict: resourcesDict)
        }
    }

    private func parseDecompressedXObjectContent(data: CFData, name: String,
                                                savedFillOpacity: Double, savedStrokeOpacity: Double,
                                                resourcesDict: CGPDFDictionaryRef? = nil) {
        guard let dataPtr = CFDataGetBytePtr(data) else {
            return
        }
        let dataLength = CFDataGetLength(data)
        let fullData = Data(bytes: dataPtr, count: dataLength)
        guard let contentString = String(data: fullData, encoding: .ascii) else {
            return
        }
        let operations = contentString.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if operations.contains("f") || operations.contains("F") {
            parseXObjectOperations(operations, name: name,
                                 savedFillOpacity: savedFillOpacity,
                                 savedStrokeOpacity: savedStrokeOpacity,
                                 resourcesDict: resourcesDict)
        }
    }

    private func parseXObjectOperations(_ operations: [String], name: String,
                                       savedFillOpacity: Double, savedStrokeOpacity: Double,
                                       resourcesDict: CGPDFDictionaryRef? = nil) {
        var i = 0
        var hasPath = false
        while i < operations.count {
            let op = operations[i]
            switch op {
            case "sc":
                if i >= 3,
                   let r = Double(operations[i - 3]),
                   let g = Double(operations[i - 2]),

                   let b = Double(operations[i - 1]) {
                    currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
                }
                i += 1
            case "m":
                if i >= 2,
                   let x = Double(operations[i - 2]),

                   let y = Double(operations[i - 1]) {
                    currentPath.append(.moveTo(CGPoint(x: x, y: y)))
                    hasPath = true
                    i += 1
                } else {
                    Log.error("\(detectedPDFVersion): XObject '\(name)' - ERROR: moveTo missing parameters before index \(i)", category: .error)
                    i += 1
                }
            case "l":
                if i >= 2,
                   let x = Double(operations[i - 2]),

                   let y = Double(operations[i - 1]) {
                    currentPath.append(.lineTo(CGPoint(x: x, y: y)))
                    hasPath = true
                    i += 1
                } else { i += 1 }
            case "c":
                if i >= 6,
                   let x1 = Double(operations[i - 6]),
                   let y1 = Double(operations[i - 5]),
                   let x2 = Double(operations[i - 4]),
                   let y2 = Double(operations[i - 3]),
                   let x3 = Double(operations[i - 2]),

                   let y3 = Double(operations[i - 1]) {
                    let cp1 = CGPoint(x: x1, y: y1)
                    let cp2 = CGPoint(x: x2, y: y2)
                    let to = CGPoint(x: x3, y: y3)
                    currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: to))
                    hasPath = true
                    i += 1
                } else { i += 1 }
            case "h":
                currentPath.append(.closePath)
                hasPath = true
                i += 1
            case "W":
                handleClipOperator()
                i += 1
            case "cm":
                if i >= 6,
                   let a = Double(operations[i - 6]),
                   let b = Double(operations[i - 5]),
                   let c = Double(operations[i - 4]),
                   let d = Double(operations[i - 3]),
                   let tx = Double(operations[i - 2]),

                   let ty = Double(operations[i - 1]) {
                    let newTransform = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
                    currentTransformMatrix = currentTransformMatrix.concatenating(newTransform)
                    i += 1
                } else { i += 1 }
            case "sh":
                if i >= 1,

                   let shadingName = operations[i - 1].hasPrefix("/") ? String(operations[i - 1].dropFirst()) : nil {
                    if let gradient = extractGradientFromXObjectResources(shadingName: shadingName, resourcesDict: resourcesDict) {
                        if hasPath {
                            let customFillStyle = FillStyle(gradient: gradient)
                            let tempFillOpacity = currentFillOpacity
                            let tempStrokeOpacity = currentStrokeOpacity
                            currentFillOpacity = savedFillOpacity
                            currentStrokeOpacity = savedStrokeOpacity
                            createShapeFromCurrentPath(filled: true, stroked: false, customFillStyle: customFillStyle)
                            currentFillOpacity = tempFillOpacity
                            currentStrokeOpacity = tempStrokeOpacity
                            hasPath = false
                        } else {
                            activeGradient = gradient
                        }
                    } else {
                        Log.error("\(detectedPDFVersion): XObject '\(name)' - ❌ Failed to extract gradient from shading '\(shadingName)'", category: .error)
                    }
                    i += 1
                } else { i += 1 }
            case "n":
                if hasPath {
                }
                i += 1
            case "Do":
                if i >= 1,

                   let xobjectName = operations[i - 1].hasPrefix("/") ? String(operations[i - 1].dropFirst()) : nil {
                    processXObjectWithImageSupport(name: xobjectName)
                    i += 1
                } else { i += 1 }
            case "f", "F":
                if hasPath {
                    let tempFillOpacity = currentFillOpacity
                    let tempStrokeOpacity = currentStrokeOpacity
                    currentFillOpacity = savedFillOpacity
                    currentStrokeOpacity = savedStrokeOpacity
                    createShapeFromCurrentPath(filled: true, stroked: false)
                    currentFillOpacity = tempFillOpacity
                    currentStrokeOpacity = tempStrokeOpacity
                    hasPath = false
                }
                i += 1
            default:
                i += 1
            }
        }
    }
}

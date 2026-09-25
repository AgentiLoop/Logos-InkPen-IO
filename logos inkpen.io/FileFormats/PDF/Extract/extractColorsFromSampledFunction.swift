import SwiftUI

extension PDFCommandParser {

    func extractColorsFromSampledFunction(_ function: CGPDFDictionaryRef) -> [VectorColor] {
        var sizeArray: CGPDFArrayRef?
        var bitsPerSample: CGPDFInteger = 8
        var domainArray: CGPDFArrayRef?
        var rangeArray: CGPDFArrayRef?
        CGPDFDictionaryGetArray(function, "Size", &sizeArray)
        CGPDFDictionaryGetInteger(function, "BitsPerSample", &bitsPerSample)
        CGPDFDictionaryGetArray(function, "Domain", &domainArray)
        CGPDFDictionaryGetArray(function, "Range", &rangeArray)
        var streamRef: CGPDFStreamRef?
        var streamData: Data?
        if CGPDFDictionaryGetStream(function, "stream", &streamRef), let stream = streamRef {
            var format: CGPDFDataFormat = CGPDFDataFormat.raw
            if let data = CGPDFStreamCopyData(stream, &format) {
                streamData = data as Data
            }
        }
        if let data = streamData {
            let cfData = data as CFData
            let dataBytes = CFDataGetBytePtr(cfData)
            let dataLength = CFDataGetLength(cfData)

            var outputComponents = 3
            if let range = rangeArray {
                outputComponents = Int(CGPDFArrayGetCount(range)) / 2
            }
            var totalSamples = 1
            if let size = sizeArray {
                let sizeCount = CGPDFArrayGetCount(size)
                for i in 0..<sizeCount {
                    var sizeValue: CGPDFInteger = 0
                    if CGPDFArrayGetInteger(size, i, &sizeValue) {
                        totalSamples *= Int(sizeValue)
                    }
                }
            }
            let bytesPerSample = Int(bitsPerSample) / 8

            var colors: [VectorColor] = []
            for sampleIndex in 0..<totalSamples {
                let baseOffset = sampleIndex * outputComponents * bytesPerSample
                if baseOffset + (outputComponents * bytesPerSample) <= dataLength {
                    var r: Double = 0, g: Double = 0, b: Double = 0
                    switch bitsPerSample {
                    case 8:
                        if outputComponents >= 3, let bytes = dataBytes {
                            r = Double(bytes[baseOffset]) / 255.0
                            g = Double(bytes[baseOffset + 1]) / 255.0
                            b = Double(bytes[baseOffset + 2]) / 255.0
                        }
                    case 16:
                        if outputComponents >= 3, let bytes = dataBytes {
                            r = Double((UInt16(bytes[baseOffset]) << 8) | UInt16(bytes[baseOffset + 1])) / 65535.0
                            g = Double((UInt16(bytes[baseOffset + 2]) << 8) | UInt16(bytes[baseOffset + 3])) / 65535.0
                            b = Double((UInt16(bytes[baseOffset + 4]) << 8) | UInt16(bytes[baseOffset + 5])) / 65535.0
                        }
                    default:
                        Log.warning("PDF: ⚠️ Unsupported bits per sample: \(bitsPerSample)", category: .general)
                        continue
                    }
                    if let range = rangeArray, CGPDFArrayGetCount(range) >= 6 {
                        var rMin: CGPDFReal = 0, rMax: CGPDFReal = 1
                        var gMin: CGPDFReal = 0, gMax: CGPDFReal = 1
                        var bMin: CGPDFReal = 0, bMax: CGPDFReal = 1
                        CGPDFArrayGetNumber(range, 0, &rMin)
                        CGPDFArrayGetNumber(range, 1, &rMax)
                        CGPDFArrayGetNumber(range, 2, &gMin)
                        CGPDFArrayGetNumber(range, 3, &gMax)
                        CGPDFArrayGetNumber(range, 4, &bMin)
                        CGPDFArrayGetNumber(range, 5, &bMax)
                        r = Double(rMin) + r * Double(rMax - rMin)
                        g = Double(gMin) + g * Double(gMax - gMin)
                        b = Double(bMin) + b * Double(bMax - bMin)
                    }
                    let color = VectorColor.rgb(RGBColor(red: r, green: g, blue: b))
                    colors.append(color)
                }
            }
            if !colors.isEmpty {
                return colors
            }
        }
        if let range = rangeArray {
            if CGPDFArrayGetCount(range) >= 6 {
                var r1: CGPDFReal = 0, r2: CGPDFReal = 1
                var g1: CGPDFReal = 0, g2: CGPDFReal = 1
                var b1: CGPDFReal = 0, b2: CGPDFReal = 1
                CGPDFArrayGetNumber(range, 0, &r1)
                CGPDFArrayGetNumber(range, 1, &r2)
                CGPDFArrayGetNumber(range, 2, &g1)
                CGPDFArrayGetNumber(range, 3, &g2)
                CGPDFArrayGetNumber(range, 4, &b1)
                CGPDFArrayGetNumber(range, 5, &b2)
                let startColor = VectorColor.rgb(RGBColor(red: Double(r1), green: Double(g1), blue: Double(b1)))
                let endColor = VectorColor.rgb(RGBColor(red: Double(r2), green: Double(g2), blue: Double(b2)))
                return [startColor, endColor]
            }
        }
        Log.warning("PDF: ⚠️ Could not extract colors from sampled function, using defaults", category: .general)
        return [.black, .white]
    }
}

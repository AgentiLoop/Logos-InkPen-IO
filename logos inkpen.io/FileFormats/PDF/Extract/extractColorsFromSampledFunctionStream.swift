import SwiftUI

extension PDFCommandParser {

    func extractColorsFromSampledFunctionStream(stream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef) -> [VectorColor] {
        var sizeArray: CGPDFArrayRef?
        var bitsPerSample: CGPDFInteger = 8
        var rangeArray: CGPDFArrayRef?
        CGPDFDictionaryGetArray(dictionary, "Size", &sizeArray)
        CGPDFDictionaryGetInteger(dictionary, "BitsPerSample", &bitsPerSample)
        CGPDFDictionaryGetArray(dictionary, "Range", &rangeArray)
        var format: CGPDFDataFormat = CGPDFDataFormat.raw
        if let data = CGPDFStreamCopyData(stream, &format) {
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
            if bitsPerSample == 8 && outputComponents >= 3 {
                var rMin: CGPDFReal = 0, rMax: CGPDFReal = 1
                var gMin: CGPDFReal = 0, gMax: CGPDFReal = 1
                var bMin: CGPDFReal = 0, bMax: CGPDFReal = 1
                if let range = rangeArray, CGPDFArrayGetCount(range) >= 6 {
                    CGPDFArrayGetNumber(range, 0, &rMin)
                    CGPDFArrayGetNumber(range, 1, &rMax)
                    CGPDFArrayGetNumber(range, 2, &gMin)
                    CGPDFArrayGetNumber(range, 3, &gMax)
                    CGPDFArrayGetNumber(range, 4, &bMin)
                    CGPDFArrayGetNumber(range, 5, &bMax)
                }
                let rangeMin: [Float] = [Float(rMin), Float(gMin), Float(bMin)]
                let rangeMax: [Float] = [Float(rMax), Float(gMax), Float(bMax)]
                if let gpuColors = PDFMetalProcessor.shared.extractGradientColors(
                    sampleData: cfData as Data,
                    totalSamples: totalSamples,
                    outputComponents: outputComponents,
                    rangeMin: rangeMin,
                    rangeMax: rangeMax
                ) {
                    return gpuColors
                }
            }
            Log.warning("⚠️ Using CPU fallback for gradient color extraction", category: .general)
            let maxSamples = 1024
            let samplingStep = max(1, totalSamples / maxSamples)
            let actualSamples = min(totalSamples, maxSamples)

            var colors: [VectorColor] = []
            colors.reserveCapacity(actualSamples)
            for i in 0..<actualSamples {
                let sampleIndex = i * samplingStep
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
        Log.warning("PDF: ⚠️ Could not extract colors from stream, using defaults", category: .general)
        return [.black, .white]
    }
}

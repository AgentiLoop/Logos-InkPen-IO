import SwiftUI

extension PDFCommandParser {

    func handleRGBFillColor(scanner: CGPDFScannerRef) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &g),
              CGPDFScannerPopNumber(scanner, &r) else {
            Log.error("PDF: Failed to read RGB fill color", category: .error)
            return
        }
        let colorSpace = ColorManager.shared.workingCGColorSpace
        guard let color = CGColor(colorSpace: colorSpace,
                                  components: [r, g, b, 1.0]) else {
            Log.error("PDF: Failed to create color in working color space for fill", category: .error)
            return
        }
        currentFillColor = color
    }

    func handleRGBStrokeColor(scanner: CGPDFScannerRef) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &g),
              CGPDFScannerPopNumber(scanner, &r) else { return }
        let colorSpace = ColorManager.shared.workingCGColorSpace
        guard let color = CGColor(colorSpace: colorSpace,
                                  components: [r, g, b, 1.0]) else {
            Log.error("PDF: Failed to create color in working color space for stroke", category: .error)
            return
        }
        currentStrokeColor = color
    }

    func handleGrayFillColor(scanner: CGPDFScannerRef) {
        var gray: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &gray) else { return }
        let colorSpace = ColorManager.shared.workingCGColorSpace
        guard let color = CGColor(colorSpace: colorSpace,
                                  components: [gray, gray, gray, 1.0]) else {
            Log.error("PDF: Failed to create gray color in working color space for fill", category: .error)
            return
        }
        currentFillColor = color
    }

    func handleGrayStrokeColor(scanner: CGPDFScannerRef) {
        var gray: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &gray) else { return }
        let colorSpace = ColorManager.shared.workingCGColorSpace
        guard let color = CGColor(colorSpace: colorSpace,
                                  components: [gray, gray, gray, 1.0]) else {
            Log.error("PDF: Failed to create gray color in working color space for stroke", category: .error)
            return
        }
        currentStrokeColor = color
    }

    func handleCMYKFillColor(scanner: CGPDFScannerRef) {
        var c: CGFloat = 0, m: CGFloat = 0, y: CGFloat = 0, k: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &k),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &m),
              CGPDFScannerPopNumber(scanner, &c) else {
            Log.error("PDF: Failed to read CMYK fill color", category: .error)
            return
        }
        let r = (1.0 - c) * (1.0 - k)
        let g = (1.0 - m) * (1.0 - k)
        let b = (1.0 - y) * (1.0 - k)
        let colorSpace = ColorManager.shared.workingCGColorSpace
        guard let color = CGColor(colorSpace: colorSpace,
                                  components: [r, g, b, 1.0]) else {
            Log.error("PDF: Failed to create color in working color space for fill", category: .error)
            return
        }
        currentFillColor = color
    }

    func handleCMYKStrokeColor(scanner: CGPDFScannerRef) {
        var c: CGFloat = 0, m: CGFloat = 0, y: CGFloat = 0, k: CGFloat = 0
        guard CGPDFScannerPopNumber(scanner, &k),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &m),
              CGPDFScannerPopNumber(scanner, &c) else {
            Log.error("PDF: Failed to read CMYK stroke color", category: .error)
            return
        }
        let r = (1.0 - c) * (1.0 - k)
        let g = (1.0 - m) * (1.0 - k)
        let b = (1.0 - y) * (1.0 - k)
        let colorSpace = ColorManager.shared.workingCGColorSpace
        guard let color = CGColor(colorSpace: colorSpace,
                                  components: [r, g, b, 1.0]) else {
            Log.error("PDF: Failed to create color in working color space for stroke", category: .error)
            return
        }
        currentStrokeColor = color
    }

    func handleGenericFillColor(scanner: CGPDFScannerRef) {
        var values: [CGFloat] = []
        var value: CGFloat = 0
        while CGPDFScannerPopNumber(scanner, &value) {
            values.insert(value, at: 0)
        }
        if values.count >= 3 {
            let r = values[0]
            let g = values[1]
            let b = values[2]
            let a = values.count >= 4 ? values[3] : 1.0
            if values.count == 4 {
                Log.warning("PDF: ⚠️ FOUND 4-component color - might be RGBA or transparency: \(values)", category: .general)
                currentFillOpacity = Double(a)
            }
            let colorSpace = ColorManager.shared.workingCGColorSpace
            guard let color = CGColor(colorSpace: colorSpace,
                                      components: [r, g, b, 1.0]) else {
                Log.error("PDF: Failed to create color in working color space for generic fill", category: .error)
                return
            }
            currentFillColor = color
        }
    }

    func handleGenericStrokeColor(scanner: CGPDFScannerRef) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        if CGPDFScannerPopNumber(scanner, &b) &&
           CGPDFScannerPopNumber(scanner, &g) &&
           CGPDFScannerPopNumber(scanner, &r) {
            let colorSpace = ColorManager.shared.workingCGColorSpace
            guard let color = CGColor(colorSpace: colorSpace,
                                      components: [r, g, b, 1.0]) else {
                Log.error("PDF: Failed to create color in working color space for generic stroke", category: .error)
                return
            }
            currentStrokeColor = color
        }
    }

    func handleFillAlpha(scanner: CGPDFScannerRef) {
        var alpha: CGFloat = 0
        if CGPDFScannerPopNumber(scanner, &alpha) {
            currentFillOpacity = Double(alpha)
        }
    }

    func handleStrokeAlpha(scanner: CGPDFScannerRef) {
        var alpha: CGFloat = 0
        if CGPDFScannerPopNumber(scanner, &alpha) {
            currentStrokeOpacity = Double(alpha)
        }
    }
}

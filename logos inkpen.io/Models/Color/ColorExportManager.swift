import SwiftUI
import UniformTypeIdentifiers

final class ColorExportManager {
    static let shared = ColorExportManager()

    private init() {}

    enum ExportFormat {
        case png
    }

    enum ColorSpaceOption {
        case displayP3
        case sRGB
        case adobeRGB
    }

    @discardableResult
    func exportImage(
        _ cgImage: CGImage,
        format: ExportFormat,
        colorSpace: ColorSpaceOption = .displayP3,
        to outputURL: URL
    ) throws -> Bool {
        let ciImage = CIImage(cgImage: cgImage)
        let targetColorSpace = getColorSpace(for: colorSpace)
        let convertedCIImage = ciImage.matchedFromWorkingSpace(to: targetColorSpace) ?? ciImage
        let context = CIContext(options: [
            .workingColorSpace: targetColorSpace,
            .outputColorSpace: targetColorSpace
        ])
        guard let finalCGImage = context.createCGImage(
            convertedCIImage,
            from: convertedCIImage.extent,
            format: .RGBA8,
            colorSpace: targetColorSpace
        ) else {
            throw ExportError.imageConversionFailed
        }
        switch format {
        case .png:
            return try exportAsPNG(finalCGImage, colorSpace: colorSpace, to: outputURL)
        }
    }

    private func exportAsPNG(
        _ cgImage: CGImage,
        colorSpace: ColorSpaceOption,
        to outputURL: URL
    ) throws -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.destinationCreationFailed
        }
        let properties = getImageProperties(for: colorSpace)
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        let fileProperties = getFileProperties(for: colorSpace)
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.finalizationFailed
        }
        return true
    }

    private func getColorSpace(for option: ColorSpaceOption) -> CGColorSpace {
        switch option {
        case .displayP3:
            return CGColorSpace(name: CGColorSpace.displayP3) ?? ColorManager.shared.displayP3CG
        case .sRGB:
            return CGColorSpace(name: CGColorSpace.sRGB) ?? ColorManager.shared.sRGBCG
        case .adobeRGB:
            return CGColorSpace(name: CGColorSpace.adobeRGB1998) ?? ColorManager.shared.sRGBCG
        }
    }

    private func getProfileName(for option: ColorSpaceOption) -> String {
        switch option {
        case .displayP3:
            return "Display P3"
        case .sRGB:
            return "sRGB IEC61966-2.1"
        case .adobeRGB:
            return "Adobe RGB (1998)"
        }
    }

    private func getImageProperties(for colorSpace: ColorSpaceOption) -> [CFString: Any] {
        return [
            kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
            kCGImagePropertyProfileName: getProfileName(for: colorSpace) as CFString,
            kCGImagePropertyHasAlpha: true as CFBoolean
        ]
    }

    private func getFileProperties(for colorSpace: ColorSpaceOption) -> [CFString: Any] {
        return [
            kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
            kCGImagePropertyProfileName: getProfileName(for: colorSpace) as CFString
        ]
    }

    enum ExportError: LocalizedError {
        case imageConversionFailed
        case destinationCreationFailed
        case finalizationFailed

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed:
                return "Failed to convert image to target color space"
            case .destinationCreationFailed:
                return "Failed to create image destination"
            case .finalizationFailed:
                return "Failed to finalize image export"
            }
        }
    }
}

extension ColorExportManager {

    @discardableResult
    func exportFromContext(
        _ context: CGContext,
        format: ExportFormat,
        colorSpace: ColorSpaceOption = .displayP3,
        to outputURL: URL
    ) throws -> Bool {
        guard let cgImage = context.makeImage() else {
            throw ExportError.imageConversionFailed
        }
        return try exportImage(cgImage, format: format, colorSpace: colorSpace, to: outputURL)
    }
}

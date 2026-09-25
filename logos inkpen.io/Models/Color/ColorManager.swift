import SwiftUI

final class ColorManager {
	static let shared = ColorManager()
	static let defaultBlue = VectorColor.rgb(RGBColor(red: 0.0, green: 0.478, blue: 1.0, colorSpace: .displayP3))
	static let defaultRed = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
	private(set) var colorDefaults: ColorDefaults

	private init() {
		colorDefaults = ColorDefaults()
	}

	enum WorkingSpace {
		case displayP3
		case sRGB
		case linearSRGB
		case extendedSRGB
	}
	private(set) var workingSpace: WorkingSpace = .displayP3

	var workingCGColorSpace: CGColorSpace {
		let fallback = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
		switch workingSpace {
		case .displayP3:
			return CGColorSpace(name: CGColorSpace.displayP3) ?? fallback
		case .sRGB:
			return CGColorSpace(name: CGColorSpace.sRGB) ?? fallback
		case .linearSRGB:
			return CGColorSpace(name: CGColorSpace.extendedLinearSRGB) ?? fallback
		case .extendedSRGB:
			return CGColorSpace(name: CGColorSpace.extendedSRGB) ?? fallback
		}
	}

	var workingSwiftUIColorSpace: Color.RGBColorSpace {
		switch workingSpace {
		case .displayP3: return .displayP3
		case .sRGB: return .sRGB
		case .linearSRGB: return .sRGBLinear
		case .extendedSRGB: return .sRGB
		}
	}

	func toWorking(_ cgColor: CGColor) -> CGColor {
		if cgColor.colorSpace == workingCGColorSpace { return cgColor }
		return cgColor.converted(to: workingCGColorSpace, intent: .relativeColorimetric, options: nil) ?? cgColor
	}

	func convert(_ cgColor: CGColor, to target: CGColorSpace) -> CGColor {
		if cgColor.colorSpace == target { return cgColor }
		return cgColor.converted(to: target, intent: .relativeColorimetric, options: nil) ?? cgColor
	}

	func makeColor(r: Double, g: Double, b: Double, a: Double = 1.0, source: CGColorSpace) -> Color {
		let components: [CGFloat] = [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)]
		guard let srcColor = CGColor(colorSpace: source, components: components) else {
			return Color(workingSwiftUIColorSpace, red: r, green: g, blue: b, opacity: a)
		}
		let working = toWorking(srcColor)
		return Color(working)
	}

	var sRGBCG: CGColorSpace {
		CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
	}

	var displayP3CG: CGColorSpace {
		CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
 }

	func cgColorToSRGBHex(_ cgColor: CGColor) -> String {
		let srgb = convert(cgColor, to: sRGBCG)
		guard let comps = srgb.components else { return "#000000" }
		let r = Int(round(Double(comps[0]) * 255.0))
		let g = Int(round(Double(comps[1]) * 255.0))
		let b = Int(round(Double(comps[2]) * 255.0))
		return String(format: "#%02X%02X%02X", r, g, b)
	}
}

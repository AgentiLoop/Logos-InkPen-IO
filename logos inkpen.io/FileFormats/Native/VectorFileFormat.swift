import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import AppKit

enum VectorFileFormat: String, CaseIterable {
    case svg = "svg"
    case pdf = "pdf"

    var displayName: String {
        switch self {
        case .svg: return "SVG (Scalable Vector Graphics)"
        case .pdf: return "PDF (Portable Document Format)"
        }
    }

    var uniformTypeIdentifier: String {
        switch self {
        case .svg: return "public.svg-image"
        case .pdf: return "com.adobe.pdf"
        }
    }

    var isCurrentlySupported: Bool {
        switch self {
        case .svg, .pdf: return true
        }
    }
}

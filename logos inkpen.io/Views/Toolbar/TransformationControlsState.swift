import SwiftUI
import Combine

final class TransformationControlsState: ObservableObject {

    @Published var xValue: String = ""
    @Published var yValue: String = ""
    @Published var widthValue: String = ""
    @Published var heightValue: String = ""
    @Published var aspectRatio: CGFloat = 1.0
    @Published var scaleXValue: String = "100"
    @Published var scaleYValue: String = "100"
    @Published var rotationValue: String = "0"
    @Published var keepProportions: Bool = false
    @Published var linkScale: Bool = true
}

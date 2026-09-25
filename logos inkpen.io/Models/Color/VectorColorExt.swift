import SwiftUI

extension VectorColor {

    var autocadColorIndex: Int {
        let red = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1))
        let yellow = VectorColor.rgb(RGBColor(red: 1, green: 1, blue: 0, alpha: 1))
        let green = VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0, alpha: 1))
        let cyan = VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 1, alpha: 1))
        let blue = VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1))
        let magenta = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 1, alpha: 1))
        if self == red { return 1 }
        if self == yellow { return 2 }
        if self == green { return 3 }
        if self == cyan { return 4 }
        if self == blue { return 5 }
        if self == magenta { return 6 }
        if self == VectorColor.white { return 7 }
        if self == VectorColor.black { return 0 }
        return 7
    }
}

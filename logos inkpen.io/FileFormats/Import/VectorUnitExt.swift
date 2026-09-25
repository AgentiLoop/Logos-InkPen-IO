import SwiftUI

extension VectorUnit {

    var pointsPerUnit_Export: CGFloat {
        switch self {
        case .points:      return 1.0
        case .inches:      return 72.0
        case .millimeters: return 2.834646
        case .pixels:      return 1.0
        case .picas:       return 12.0
        }
    }

    var millimetersPerUnit: CGFloat {
        switch self {
        case .millimeters: return 1.0
        case .inches:      return 25.4
        case .points:      return 0.352777778
        case .picas:       return 4.233333333
        case .pixels:      return 0.352777778
        }
    }

    func convertTo(_ targetUnit: VectorUnit, value: CGFloat) -> CGFloat {
        let valueInMM = value * self.millimetersPerUnit
        let result = valueInMM / targetUnit.millimetersPerUnit
        return round(result * 1000000) / 1000000
    }

    var scaleFactorFor100Percent: CGFloat {
        return 1.0
    }
}

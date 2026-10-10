import SwiftUI

struct ToolGroupConfiguration {
    static let toolGroupConfig: [String: [DrawingTool]] = [
        "selection": [.selection, .cornerRadius],
        "directSelection": [.directSelection, .convertAnchorPoint, .penPlusMinus],
        "rectangles": [.rectangle, .square, .roundedRectangle, .pill],
        "circles": [.ellipse, .oval, .circle, .egg],
        "triangles": [.equilateralTriangle, .rightTriangle, .acuteTriangle, .cone],
        "polygons": [.pentagon, .hexagon, .heptagon, .octagon, .nonagon],
        "lines": [.bezierPen, .line],
        "brushes": [.brush, .marker, .freehand],
        "transforms": [.scale, .rotate, .reflect, .shear, .warp],
        "stars": [.star],
        "scissors": [.scissors, .knife],
        "navigation": [.hand, .zoom],
        "utilities": [.eyedropper, .selectSameColor, .gradient]
    ]

    static func getToolGroup(for tool: DrawingTool) -> [DrawingTool] {
        for (_, tools) in toolGroupConfig {
            if tools.contains(tool) {
                return tools
            }
        }
        return [tool]
    }

    static func getToolGroupName(for tool: DrawingTool) -> String? {
        for (groupName, tools) in toolGroupConfig {
            if tools.contains(tool) {
                return groupName
            }
        }
        return nil
    }

    static func getAllToolGroupsAsArrays() -> [[DrawingTool]] {
        let orderedGroupNames = [
            "selection",
            "directSelection",
            "lines",
            "transforms",
            "brushes",
            "font",
            "rectangles",
            "circles",
            "triangles",
            "polygons",
            "stars",
            "scissors",
            "utilities",
            "navigation"
        ]
        var allGroups: [[DrawingTool]] = []
        for groupName in orderedGroupNames {
            if let group = toolGroupConfig[groupName] {
                allGroups.append(group)
            } else if groupName == "font" {
                allGroups.append([.font])
            }
        }
        return allGroups
    }
}

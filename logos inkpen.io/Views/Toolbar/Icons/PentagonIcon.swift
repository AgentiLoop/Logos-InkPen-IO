import SwiftUI

private func polygonIconPath(center: CGPoint, radius: CGFloat, sides: Int) -> Path {
    var p = Path()

    let adjustedRadius = radius + IconStrokeExpand
    let angleStep = (2.0 * .pi) / Double(sides)
    let startAngle = -Double.pi / 2 + ((sides % 2 == 0) ? angleStep / 2 : 0)
    for i in 0..<sides {
        let angle = Double(i) * angleStep + startAngle
        let x = center.x + adjustedRadius * cos(CGFloat(angle))
        let y = center.y + adjustedRadius * sin(CGFloat(angle))
        if i == 0 {
            p.move(to: CGPoint(x: x, y: y))
        } else {
            p.addLine(to: CGPoint(x: x, y: y))
        }
    }
    p.closeSubpath()
    return p
}

struct PentagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 5)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

struct HexagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 6)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

struct HeptagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 7)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

struct OctagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 8)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

struct NonagonIcon: View { let isSelected: Bool; var body: some View {
    polygonIconPath(center: CGPoint(x: 10, y: 10), radius: 7, sides: 9)
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
}}

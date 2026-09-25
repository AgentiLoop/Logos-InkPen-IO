import SwiftUI
import AppKit

struct VerticalToolbar: View {
    let currentTool: DrawingTool

    @ObservedObject var viewState: DocumentViewState

    let document: VectorDocument

    @Binding var colorDeltaColor: VectorColor?
    @Binding var colorDeltaOpacity: Double?
    @Binding var colorDeltaBlendMode: BlendMode?
    @Binding var defaultFillColor: VectorColor
    @Binding var defaultStrokeColor: VectorColor

    @ObservedObject private var toolGroupManager = ToolGroupManager.shared
    private func handleToolLongPress(_ tool: DrawingTool, variantIndex: Int? = nil) {
        toolGroupManager.longPressedTool(tool, variantIndex: variantIndex)
    }

    @ViewBuilder
    private func toolIconView(for toolItem: ToolItem) -> some View {
        if toolItem.tool == .shear {
            SkewedRectangleIcon(isSelected: currentTool == toolItem.tool)
        } else if toolItem.tool == .star, let starVariant = toolItem.starVariant {
            starVariant.iconView(
                isSelected: currentTool == .star && toolGroupManager.selectedVariant == starVariant,
                color: (currentTool == .star && toolGroupManager.selectedVariant == starVariant) ? .white : .primary
            )
        } else if toolItem.tool == .star {
            toolGroupManager.selectedVariant.iconView(
                isSelected: currentTool == toolItem.tool,
                color: currentTool == toolItem.tool ? .white : .primary
            )
        } else {
            customShapeIconView(for: toolItem)
        }
    }

    @ViewBuilder
    private func customShapeIconView(for toolItem: ToolItem) -> some View {
        switch toolItem.tool {
        case .rectangle:
            RectangleIcon(isSelected: currentTool == toolItem.tool)
        case .square:
            SquareIcon(isSelected: currentTool == toolItem.tool)
        case .roundedRectangle:
            RoundedRectangleIcon(isSelected: currentTool == toolItem.tool)
        case .pill:
            PillIcon(isSelected: currentTool == toolItem.tool)
        case .ellipse:
            EllipseIcon(isSelected: currentTool == toolItem.tool)
        case .oval:
            OvalIcon(isSelected: currentTool == toolItem.tool)
        case .circle:
            CircleIcon(isSelected: currentTool == toolItem.tool)
        case .egg:
            EggIcon(isSelected: currentTool == toolItem.tool)
        case .cone:
            ConeIcon(isSelected: currentTool == toolItem.tool)
        case .equilateralTriangle:
            EquilateralTriangleIcon(isSelected: currentTool == toolItem.tool)
        case .rightTriangle:
            RightTriangleIcon(isSelected: currentTool == toolItem.tool)
        case .acuteTriangle:
            AcuteTriangleIcon(isSelected: currentTool == toolItem.tool)
        case .pentagon:
            PentagonIcon(isSelected: currentTool == toolItem.tool)
        case .hexagon:
            HexagonIcon(isSelected: currentTool == toolItem.tool)
        case .heptagon:
            HeptagonIcon(isSelected: currentTool == toolItem.tool)
        case .octagon:
            OctagonIcon(isSelected: currentTool == toolItem.tool)
        case .nonagon:
            NonagonIcon(isSelected: currentTool == toolItem.tool)
        default:
            Image(systemName: toolItem.tool.iconName)
                .font(.system(size: 16))
                .foregroundColor(isToolSelected(toolItem) ? .white : .primary)
        }
    }

    private func getToolsToDisplayByGroup() -> [[ToolItem]] {
        var toolGroups: [[ToolItem]] = []

        let allToolGroups = getAllToolGroups()
        for toolGroup in allToolGroups {
            var groupTools: [ToolItem] = []

            let primaryTool = toolGroup[0]
            let groupName = ToolGroupConfiguration.getToolGroupName(for: primaryTool) ?? "single:\(primaryTool.rawValue)"
            if toolGroupManager.expandedGroups.contains(groupName) {
                if primaryTool == .star {
                    if let anchorVariant = (toolGroupManager.anchorVariantByGroup[groupName] ?? nil) {
                        groupTools.append(ToolItem(tool: .star, starVariant: anchorVariant))
                        let otherVariants = StarVariant.allCases.filter { $0 != anchorVariant }
                        for variant in otherVariants {
                            groupTools.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    } else {
                        for variant in StarVariant.allCases {
                            groupTools.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    }
                } else {
                    let orderedTools = toolGroupManager.getOrderedToolsForGroup(groupName, defaultTools: toolGroup)
                    for tool in orderedTools {
                        groupTools.append(ToolItem(tool: tool, starVariant: nil))
                    }
                }
            } else {
                if primaryTool == .star {
                    groupTools.append(ToolItem(tool: .star, starVariant: toolGroupManager.selectedVariant))
                } else {
                    let selectedTool = toolGroupManager.selectedToolByGroup[groupName] ?? primaryTool
                    groupTools.append(ToolItem(tool: selectedTool, starVariant: nil))
                }
            }
            if !groupTools.isEmpty {
                toolGroups.append(groupTools)
            }
        }
        return toolGroups
    }

    private func getToolsToDisplay() -> [ToolItem] {
        var toolsToShow: [ToolItem] = []

        let allToolGroups = getAllToolGroups()
        for toolGroup in allToolGroups {
            let primaryTool = toolGroup[0]
            let groupName = ToolGroupConfiguration.getToolGroupName(for: primaryTool) ?? "single:\(primaryTool.rawValue)"
            if toolGroupManager.expandedGroups.contains(groupName) {
                if primaryTool == .star {
                    if let anchorVariant = (toolGroupManager.anchorVariantByGroup[groupName] ?? nil) {
                        toolsToShow.append(ToolItem(tool: .star, starVariant: anchorVariant))
                        let otherVariants = StarVariant.allCases.filter { $0 != anchorVariant }
                        for variant in otherVariants {
                            toolsToShow.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    } else {
                        for variant in StarVariant.allCases {
                            toolsToShow.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    }
                } else {
                    for tool in toolGroup {
                        toolsToShow.append(ToolItem(tool: tool, starVariant: nil))
                    }
                }
            } else {
                if primaryTool == .star {
                    toolsToShow.append(ToolItem(tool: .star, starVariant: toolGroupManager.selectedVariant))
                } else {
                    let selectedTool = toolGroupManager.selectedToolByGroup[groupName] ?? primaryTool
                    toolsToShow.append(ToolItem(tool: selectedTool, starVariant: nil))
                }
            }
        }
        return toolsToShow
    }

    private func getAllToolGroups() -> [[DrawingTool]] {
        var groups = ToolGroupConfiguration.getAllToolGroupsAsArrays()
        if let idx = groups.firstIndex(where: { $0.contains(.pentagon) && $0.contains(.octagon) }) {
            groups[idx] = [.pentagon, .hexagon, .heptagon, .octagon, .nonagon]
        }
        return groups
    }

    private func isToolSelected(_ toolItem: ToolItem) -> Bool {
        if let starVariant = toolItem.starVariant {
            return currentTool == .star && toolGroupManager.selectedVariant == starVariant
        } else {
            return currentTool == toolItem.tool
        }
    }

    private func isToolInExpandableGroup(_ toolItem: ToolItem) -> Bool {
        let tool = toolItem.tool
        let group = ToolGroupConfiguration.getToolGroup(for: tool)
        if tool == .star {
            return true
        }
        return group.count > 1
    }

    private func isGroupExpanded(for toolItem: ToolItem) -> Bool {
        let tool = toolItem.tool
        if tool == .star {
            let groupName = "stars"
            return toolGroupManager.expandedGroups.contains(groupName)
        } else if let groupName = ToolGroupConfiguration.getToolGroupName(for: tool) {
            return toolGroupManager.expandedGroups.contains(groupName)
        }
        return false
    }

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ToolSection {
                        VStack(spacing: 0) {
                            let toolsByGroup = getToolsToDisplayByGroup()
                            ForEach(Array(toolsByGroup.enumerated()), id: \.offset) { index, toolGroup in
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.2))
                                        .frame(height: 0.5)
                                        .frame(maxWidth: .infinity)
                                }
                                ForEach(toolGroup, id: \.toolIdentifier) { toolItem in
                                    VerticalToolbarButton(
                                        toolItem: toolItem,
                                        isSelected: isToolSelected(toolItem),
                                        isExpandable: isToolInExpandableGroup(toolItem),
                                        isGroupExpanded: isGroupExpanded(for: toolItem),
                                        onTap: {
                                            if let starVariant = toolItem.starVariant {
                                                toolGroupManager.selectStarVariant(starVariant)
                                                document.viewState.currentTool = .star
                                                toolGroupManager.setSelectedToolInGroup(.star)
                                            } else {
                                                document.viewState.currentTool = toolItem.tool
                                                toolGroupManager.setSelectedToolInGroup(toolItem.tool)
                                            }
                                        },
                                        onLongPress: {
                                            if let starVariant = toolItem.starVariant {
                                                let variantIndex = StarVariant.allCases.firstIndex(of: starVariant) ?? 0
                                                handleToolLongPress(.star, variantIndex: variantIndex)
                                            } else {
                                                handleToolLongPress(toolItem.tool)
                                            }
                                        },
                                        toolIconView: { toolIconView(for: toolItem) }
                                    )
                                    .help(toolTooltip(for: toolItem.tool, variant: toolItem.starVariant))
                                    .background(
                                        GeometryReader { geometry in
                                            Color.clear
                                                .onAppear {
                                                    let globalFrame = geometry.frame(in: .global)
                                                    toolGroupManager.setToolButtonFrame(toolItem.tool, frame: globalFrame)
                                                }
                                                .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                                                    toolGroupManager.setToolButtonFrame(toolItem.tool, frame: newFrame)
                                                }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    Divider()
                    ToolSection {
                        ColorSwatchGrid(
                            document: document,
                            defaultFillColor: $defaultFillColor,
                            defaultStrokeColor: $defaultStrokeColor
                        )
                    }
                    Spacer()
                }
                .padding(.bottom, 4)
                .frame(width: 48)
            }
            .background(Color.platformControlBackground)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
                alignment: .trailing
            )
        }
    }

    private func toolTooltip(for tool: DrawingTool, variant: StarVariant? = nil) -> String {
        if let starVariant = variant {
            return "Star Tool - Draw \(starVariant.rawValue) (Long press for more variants)"
        }
        switch tool {
        case .selection:
            return "Selection Tool (V) - Select and move objects"
        case .scale:
            return "Scale Tool (S) - Scale objects with corner handles"
        case .rotate:
            return "Rotate Tool (R) - Rotate objects around anchor points"
        case .reflect:
            return "Reflect Tool - Mirror objects across an interactive axis"
        case .shear:
            return "Shear Tool (X) - Shear/skew objects around anchor points"
        case .directSelection:
            return "Direct Selection Tool (A) - Edit individual points and handles"
        case .convertAnchorPoint:
            return "Convert Anchor Point Tool (C) - Convert between smooth and corner points"
        case .penPlusMinus:
            return "Pen +/- Tool (+/-) - Add points to curves or delete points from paths"
        case .bezierPen:
            return "Bezier Pen Tool (P) - Draw bezier curves and paths"
        case .freehand:
            return "Freehand Tool (F) - Draw freehand with smooth curves"
        case .brush:
            return "Brush Tool (B) - Draw variable width brush strokes"
        case .marker:
            return "Marker Tool (M) - Draw with pressure-sensitive marker strokes"
        case .font:
            return "Font Tool (T) - Add and edit text"
        case .line:
            return "Line Tool (L) - Draw straight lines"
        case .rectangle:
            return "Rectangle Tool (⌥R) - Draw rectangles"
        case .square:
            return "Square Tool (⌥S) - Draw perfect squares"
        case .roundedRectangle:
            return "Rounded Rectangle Tool (⇧⌥R) - Draw rectangles with rounded corners"
        case .pill:
            return "Pill Tool (⇧⌥P) - Draw capsule/pill shapes"
        case .circle:
            return "Circle Tool (⌥C) - Draw perfect circles"
        case .ellipse:
            return "Ellipse Tool (E) - Draw ellipses and ovals"
        case .oval:
            return "Oval Tool (O) - Draw oval shapes"
        case .egg:
            return "Egg Tool (⇧E) - Draw egg shapes"
        case .cone:
            return "Cone Tool (⇧⌥C) - Draw triangle/cone shapes"
        case .equilateralTriangle:
            return "Equilateral Triangle Tool (⇧T) - Draw triangles with equal sides"
        case .isoscelesTriangle:
            return "Isosceles Triangle Tool (I) - Draw triangles with two equal sides"
        case .rightTriangle:
            return "Right Triangle Tool (⇧⌥R) - Draw 90-degree triangles"
        case .acuteTriangle:
            return "Acute Triangle Tool (⇧A) - Draw triangles with all angles less than 90°"
        case .star:
            return "Star Tool (⇧S) - Draw \(toolGroupManager.selectedVariant.rawValue) (Long press for more variants)"
        case .polygon:
            return "Polygon Tool (⌥P) - Draw polygon shapes"
        case .pentagon:
            return "Pentagon Tool (5) - Draw 5-sided polygons"
        case .hexagon:
            return "Hexagon Tool (6) - Draw 6-sided polygons"
        case .heptagon:
            return "Heptagon Tool (7) - Draw 7-sided polygons"
        case .octagon:
            return "Octagon Tool (8) - Draw 8-sided polygons"
        case .nonagon:
            return "Nonagon Tool (9) - Draw 9-sided polygons"
        case .eyedropper:
            return "Eyedropper Tool (I) - Sample colors"
        case .selectSameColor:
            return "Select Same Color Tool - Select all objects with the same color"
        case .hand:
            return "Hand Tool (H) - Pan the canvas"
        case .zoom:
            return "Zoom Tool (Z) - Zoom in and out"
        case .warp:
            return "Warp Tool (W) - Warp and distort objects"
        case .gradient:
            return "Gradient Tool (G) - Edit gradient origin and focal points"
        case .cornerRadius:
            return "Corner Radius Tool (⌥R) - Edit corner radius of rectangles"
        }
    }
}

struct VerticalToolbarButton: View {
    let toolItem: ToolItem
    let isSelected: Bool
    let isExpandable: Bool
    let isGroupExpanded: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let toolIconView: () -> AnyView

    @State private var inc: Double = 0.0
    @State private var shouldRepeat: Bool = true
    @State private var lastTappedTool: String = ""
    init(toolItem: ToolItem,
         isSelected: Bool,
         isExpandable: Bool,
         isGroupExpanded: Bool,
         onTap: @escaping () -> Void,
         onLongPress: @escaping () -> Void,
         toolIconView: @escaping () -> some View) {
        self.toolItem = toolItem
        self.isSelected = isSelected
        self.isExpandable = isExpandable
        self.isGroupExpanded = isGroupExpanded
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.toolIconView = { AnyView(toolIconView()) }
    }

    fileprivate func FreeHandMXLongPress() {
        inc += 0.1
        lastTappedTool = toolItem.tool.rawValue
        onTap()
        if inc <= 0.1 {
            shouldRepeat = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            inc = 0.0
            shouldRepeat = true
            lastTappedTool = ""
        }
        if shouldRepeat {
            if inc > 0.1 {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if inc >= 0.3 && lastTappedTool == toolItem.tool.rawValue  {
                onLongPress()
                shouldRepeat = false
                inc = 0.0
            }
        }
    }

    var body: some View {
        Button(action: {
            FreeHandMXLongPress()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 100)
                    .fill(isSelected
                          ? InkPenUIColors.shared.toolSelectionBlue
                          : Color.clear)
                    .frame(width: 47, height: 34)
                toolIconView()
                    .frame(width: 47)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 6))
                    path.addLine(to: CGPoint(x: 6, y: 0))
                    path.addLine(to: CGPoint(x: 6, y: 6))
                    path.closeSubpath()
                }
                .fill((isSelected && isExpandable && !isGroupExpanded)
                      ? Color(.displayP3, red: 1.0, green: 0.584, blue: 0.0)
                      : Color.clear)
                .frame(width: 6, height: 6)
                .position(x: 42, y: 26)
            }
            .contentShape(Rectangle())
            .frame(width: 58, height: 34)
            .position(x: 24.5, y: 17)
        }
        .buttonStyle(BorderlessButtonStyle())
        .buttonRepeatBehavior(shouldRepeat ? .enabled : .disabled)
    }
}

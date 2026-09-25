import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class SlidingPopoverManager: NSObject {
    #if os(macOS)
    private var popover: NSPopover?
    private var currentAnchorView: NSView?
    #else
    private var popoverController: UIViewController?
    private var currentAnchorView: UIView?

    private weak var presentingViewController: UIViewController?
    #endif
    private var dismissCallback: (() -> Void)?
    #if os(macOS)

    func show<Content: View>(content: Content, anchorView: NSView, edge: Edge = .leading, onDismiss: (() -> Void)? = nil) {
        self.dismissCallback = onDismiss
        if let existingPopover = popover, existingPopover.isShown {
            slideToNewAnchor(anchorView: anchorView, edge: edge, updateContent: {
                if let hostingController = existingPopover.contentViewController as? NSHostingController<Content> {
                    hostingController.rootView = content
                } else {
                    let hostingController = NSHostingController(rootView: content)
                    hostingController.sizingOptions = [.intrinsicContentSize]
                    existingPopover.contentViewController = hostingController
                }
            })
        } else {
            let hostingController = NSHostingController(rootView: content)
            hostingController.sizingOptions = [.intrinsicContentSize]
            let newPopover = NSPopover()
            newPopover.contentViewController = hostingController
            newPopover.behavior = .transient
            newPopover.animates = true
            newPopover.delegate = self
            if let popoverView = newPopover.contentViewController?.view {
                popoverView.wantsLayer = true
                popoverView.layer?.backgroundColor = PlatformColor.clear.cgColor
            }
            let nsRectEdge = edge.toNSRectEdge()
            let positioningRect = calculatePositioningRect(for: anchorView, edge: nsRectEdge)
            newPopover.show(relativeTo: positioningRect, of: anchorView, preferredEdge: nsRectEdge)
            self.popover = newPopover
            self.currentAnchorView = anchorView
        }
    }
    #else

    func show<Content: View>(content: Content, anchorView: UIView, edge: Edge = .leading, onDismiss: (() -> Void)? = nil) {
        self.dismissCallback = onDismiss
        if presentingViewController == nil {
            presentingViewController = anchorView.viewController
        }
        guard let presentingVC = presentingViewController else { return }
        if let existingController = popoverController, existingController.presentingViewController != nil {
            if let hostingController = existingController as? UIHostingController<Content> {
                hostingController.rootView = content
            } else {
                existingController.dismiss(animated: false) {
                    self.showNewPopover(content: content, anchorView: anchorView, edge: edge, presentingVC: presentingVC)
                }
                return
            }
            if let popover = existingController.popoverPresentationController {
                popover.sourceView = anchorView
                popover.sourceRect = calculatePositioningRect(for: anchorView, edge: edge)
                popover.permittedArrowDirections = edge.toUIPopoverArrowDirection()
            }
            self.currentAnchorView = anchorView
        } else {
            showNewPopover(content: content, anchorView: anchorView, edge: edge, presentingVC: presentingVC)
        }
    }

    private func showNewPopover<Content: View>(content: Content, anchorView: UIView, edge: Edge, presentingVC: UIViewController) {
        let hostingController = UIHostingController(rootView: content)
        hostingController.modalPresentationStyle = .popover
        if let popover = hostingController.popoverPresentationController {
            popover.sourceView = anchorView
            popover.sourceRect = calculatePositioningRect(for: anchorView, edge: edge)
            popover.permittedArrowDirections = edge.toUIPopoverArrowDirection()
            popover.delegate = self
        }
        presentingVC.present(hostingController, animated: true)
        self.popoverController = hostingController
        self.currentAnchorView = anchorView
    }
    #endif
    #if os(macOS)

    private func slideToNewAnchor(anchorView: NSView, edge: Edge, updateContent: () -> Void) {
        guard let popover = popover, popover.isShown else { return }
        updateContent()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            let nsRectEdge = edge.toNSRectEdge()
            let positioningRect = calculatePositioningRect(for: anchorView, edge: nsRectEdge)
            popover.show(relativeTo: positioningRect, of: anchorView, preferredEdge: nsRectEdge)
        }
        self.currentAnchorView = anchorView
    }

    private func calculatePositioningRect(for anchorView: NSView, edge: NSRectEdge) -> CGRect {
        let bounds = anchorView.bounds
        return CGRect(
            x: bounds.origin.x + 17,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )
    }
    #else

    private func calculatePositioningRect(for anchorView: UIView, edge: Edge) -> CGRect {
        let bounds = anchorView.bounds
        return CGRect(
            x: bounds.origin.x + 17,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )
    }
    #endif

    func dismiss() {
        dismissCallback = nil
        #if os(macOS)
        popover?.performClose(nil)
        popover = nil
        #else
        popoverController?.dismiss(animated: true)
        popoverController = nil
        #endif
        currentAnchorView = nil
    }

    var isShown: Bool {
        #if os(macOS)
        return popover?.isShown ?? false
        #else
        return popoverController?.presentingViewController != nil
        #endif
    }
}
#if os(macOS)

extension SlidingPopoverManager: NSPopoverDelegate {

    func popoverWillClose(_ notification: Notification) {
        dismissCallback?()
    }

    func popoverDidClose(_ notification: Notification) {
        dismissCallback = nil
        popover = nil
        currentAnchorView = nil
    }
}
#else

extension SlidingPopoverManager: UIPopoverPresentationControllerDelegate {

    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        dismissCallback?()
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        dismissCallback = nil
        popoverController = nil
        currentAnchorView = nil
    }
}
#endif
#if os(macOS)

extension Edge {

    func toNSRectEdge() -> NSRectEdge {
        switch self {
        case .leading: return .minX
        case .trailing: return .maxX
        case .top: return .maxY
        case .bottom: return .minY
        }
    }
}
#else

extension Edge {

    func toUIPopoverArrowDirection() -> UIPopoverArrowDirection {
        switch self {
        case .leading: return .left
        case .trailing: return .right
        case .top: return .up
        case .bottom: return .down
        }
    }
}

extension UIView {

    var viewController: UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
}
#endif

struct GlassCloseButton: View {
    let action: () -> Void

    var body: some View {
        if #available(macOS 26.0, *) {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
            }
            .clipShape(.circle)
            .buttonStyle(.glass)
            .glassEffect(.regular, in: .circle)
            .padding(.top, 12)
            .padding(.trailing, 8)
        } else {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.platformWindowBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .buttonStyle(BorderlessButtonStyle())
            .clipShape(Circle())
            .padding(.top, 12)
            .padding(.trailing, 8)
        }
    }
}
#if os(macOS)

struct PopoverAnchorView: NSViewRepresentable {
    let onViewCreated: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.onViewCreated(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }
}
#else

struct PopoverAnchorView: UIViewRepresentable {
    let onViewCreated: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            self.onViewCreated(view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}
#endif

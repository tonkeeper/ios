import SwiftUI
import UIKit

public extension View {
    func tkImmediateButtonPresses() -> some View {
        modifier(ImmediateButtonPressesModifier())
    }
}

private struct ImmediateButtonPressesModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(ImmediateButtonPressesView())
    }
}

private struct ImmediateButtonPressesView: UIViewRepresentable {
    func makeUIView(context: Context) -> ImmediateButtonPressesUIView {
        let view = ImmediateButtonPressesUIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ImmediateButtonPressesUIView, context: Context) {}
}

/// Inside UISheetPresentationController the scroll pan doesn't cancel touches that were
/// delivered immediately (delaysContentTouches = false), so a scroll starting on a button
/// also fires its tap. This no-op pan recognizes alongside scrolling and cancels them.
private final class CancelTouchesOnScrollPanGestureRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = true
        delegate = self
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

private final class ImmediateButtonPressesUIView: UIView {
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        configureScrollView()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        configureScrollView()
        DispatchQueue.main.async { [weak self] in
            self?.configureScrollView()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureScrollView()
    }

    private func configureScrollView() {
        var view: UIView? = self
        while let currentView = view {
            let scrollViews = scrollViews(in: currentView)
            if !scrollViews.isEmpty {
                scrollViews.forEach(configure)
                return
            }
            view = currentView.superview
        }
    }

    private func configure(_ scrollView: UIScrollView) {
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        let hasCancelPan = scrollView.gestureRecognizers?
            .contains { $0 is CancelTouchesOnScrollPanGestureRecognizer } ?? false
        if !hasCancelPan {
            scrollView.addGestureRecognizer(CancelTouchesOnScrollPanGestureRecognizer())
        }
        DispatchQueue.main.async { [weak scrollView] in
            scrollView?.delaysContentTouches = false
            scrollView?.canCancelContentTouches = true
        }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        var result = [UIScrollView]()
        if let scrollView = view as? UIScrollView {
            result.append(scrollView)
        }
        for subview in view.subviews {
            result.append(contentsOf: scrollViews(in: subview))
        }
        return result
    }
}

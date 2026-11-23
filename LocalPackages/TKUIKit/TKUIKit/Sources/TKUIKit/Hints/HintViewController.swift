import TKLogging
import UIKit

final class HintViewController: UIViewController {
    var didTapToDismiss: (() -> Void)?
    var didLoseSourceView: (() -> Void)?
    var didTapHintContent: (() -> Void)?
    var didTapTargetActionView: (() -> Void)?
    var didHide: (() -> Void)?

    private let dismissControl = TargetActionDismissControl()
    private let contentLayoutTracker = HintContentLayoutTracker()
    private var contentViewController: UIViewController?
    private lazy var tapThroughRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTapThroughHint(_:)))
        recognizer.delegate = self
        return recognizer
    }()

    private var hintResolvedPayload: (
        position: HintPosition,
        animation: HintAnimationStyle
    )?

    private var hintView: HintContainerView {
        view as! HintContainerView
    }

    override func loadView() {
        view = HintContainerView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        dismissControl.accessibilityIdentifier = "tooltip_dismiss"
        view.addSubview(dismissControl)

        contentLayoutTracker.onSourceViewLost = { [weak self] in
            self?.didLoseSourceView?()
        }

        dismissControl.addTarget(self, action: #selector(didTapDismissControl(_:)), for: .touchUpInside)
        dismissControl.didTapTargetActionView = { [weak self] view in
            self?.performTargetAction(of: view)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        dismissControl.frame = view.bounds
    }

    func showHint(
        sourceView: UIView,
        sourceWindow: UIWindow,
        configuration: HintConfiguration,
        targetActionViews: [UIView],
        contentViewControllerProvider: @escaping (HintPosition.Direction?) -> UIViewController
    ) {
        hintView.sourceView = sourceView
        hintView.targetActionViews = targetActionViews
        dismissControl.targetActionViews = targetActionViews
        sourceWindow.addGestureRecognizer(tapThroughRecognizer)

        let contentViewControllerToResolvePosition = contentViewControllerProvider(nil)

        let (contentFrame, resolvedPosition) = contentLayoutTracker.resolveLayout(
            sourceView: sourceView,
            sourceWindow: sourceWindow,
            configuration: configuration,
            contentViewController: contentViewControllerToResolvePosition
        )

        let contentViewController = contentViewControllerProvider(resolvedPosition.direction)
        contentViewController.view.alpha = 0
        installContent(
            contentViewController,
            sourceView: sourceView,
            sourceWindow: sourceWindow,
            configuration: configuration,
            position: resolvedPosition,
            frame: contentFrame
        )

        contentLayoutTracker.onPositionFlip = { [weak self, weak sourceView, weak sourceWindow] position, frame in
            guard
                let self,
                let sourceView,
                let sourceWindow,
                let previousContentViewController = self.contentViewController
            else {
                return
            }
            removeContent(previousContentViewController)
            installContent(
                contentViewControllerProvider(position.direction),
                sourceView: sourceView,
                sourceWindow: sourceWindow,
                configuration: configuration,
                position: position,
                frame: frame
            )
        }

        let animator: HintAnimator
        switch configuration.animationStyle {
        case .bouncing:
            animator = BouncingHintAnimator()
        }
        animator.show(view: contentViewController.view, for: resolvedPosition, completion: {})
    }

    func hideHint(completion: @escaping () -> Void) {
        contentLayoutTracker.reset()
        tapThroughRecognizer.view?.removeGestureRecognizer(tapThroughRecognizer)
        guard let contentViewController else {
            clearTargetActionViews()
            completion()
            return
        }
        let animator: HintAnimator
        switch hintResolvedPayload?.animation {
        case .bouncing, .none:
            animator = BouncingHintAnimator()
        }

        animator.hide(
            view: contentViewController.view,
            for: hintResolvedPayload?.position
        ) {
            self.removeContent(contentViewController)
            self.hintResolvedPayload = nil
            self.clearTargetActionViews()
            completion()
        }
    }

    func removeHint() {
        contentLayoutTracker.reset()
        tapThroughRecognizer.view?.removeGestureRecognizer(tapThroughRecognizer)
        if let contentViewController {
            removeContent(contentViewController)
        }
        hintResolvedPayload = nil
        clearTargetActionViews()
    }

    @objc
    private func didTapDismissControl(_ sender: UIControl) {
        didTapToDismiss?()
    }

    @objc
    private func didTapContentView(_ sender: UITapGestureRecognizer) {
        didTapHintContent?()
    }

    @objc
    private func didTapThroughHint(_ recognizer: UITapGestureRecognizer) {
        if let targetActionView = dismissControl.targetActionView(at: recognizer.location(in: dismissControl)) {
            performTargetAction(of: targetActionView)
        } else {
            didTapToDismiss?()
        }
    }
}

extension HintViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard hintView.letsScrollThrough, let contentView = contentViewController?.view else {
            return false
        }
        return !contentView.bounds.contains(touch.location(in: contentView))
    }

    /// The views under a hint that lets scrolls through wait for its tap to fail, so a tap still only closes it.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        hintView.letsScrollThrough
    }
}

private extension HintViewController {
    func installContent(
        _ contentViewController: UIViewController,
        sourceView: UIView,
        sourceWindow: UIWindow,
        configuration: HintConfiguration,
        position: HintPosition,
        frame: CGRect
    ) {
        self.contentViewController = contentViewController

        addChild(contentViewController)
        view.insertSubview(contentViewController.view, aboveSubview: dismissControl)
        contentViewController.didMove(toParent: self)
        contentViewController.view.translatesAutoresizingMaskIntoConstraints = false
        contentViewController.view.accessibilityIdentifier = "tooltip"
        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(didTapContentView(_:))
        )
        contentViewController.view.addGestureRecognizer(tapGestureRecognizer)

        contentLayoutTracker.install(
            contentViewController: contentViewController,
            in: view,
            sourceView: sourceView,
            sourceWindow: sourceWindow,
            configuration: configuration,
            resolvedPosition: position,
            initialFrame: frame
        )
        view.layoutIfNeeded()

        hintResolvedPayload = (position, configuration.animationStyle)
        contentViewController.view.layoutIfNeeded()
    }

    func removeContent(_ contentViewController: UIViewController) {
        contentViewController.willMove(toParent: nil)
        contentViewController.view.removeFromSuperview()
        contentViewController.removeFromParent()
        if self.contentViewController === contentViewController {
            self.contentViewController = nil
        }
    }

    func clearTargetActionViews() {
        hintView.targetActionViews = []
        dismissControl.targetActionViews = []
    }

    func performTargetAction(of view: UIView) {
        if let control = view as? UIControl {
            control.sendActions(for: .touchUpInside)
            control.sendActions(for: .primaryActionTriggered)
        }
        didTapTargetActionView?()
    }
}

private final class HintContainerView: UIView {
    var targetActionViews = [UIView]()
    weak var sourceView: UIView?
    /// Turns on for good once a touch comes while the source is cut off by its scroll view: from then on only
    /// the hint itself takes touches, so the user can scroll to the source.
    private(set) var letsScrollThrough = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if !letsScrollThrough, let sourceView, let window, sourceView.hintAnchor(in: window).isClipped {
            letsScrollThrough = true
        }
        if letsScrollThrough, hitView === self || hitView is TargetActionDismissControl {
            return nil
        }
        guard hitView === self, shouldBypassForTargetActionView(point) else {
            return hitView
        }
        return nil
    }

    private func shouldBypassForTargetActionView(_ point: CGPoint) -> Bool {
        targetActionViews.contains { isTappableTargetActionView($0, at: point) }
    }
}

private final class TargetActionDismissControl: UIControl {
    var targetActionViews = [UIView]()
    var didTapTargetActionView: ((UIView) -> Void)?

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            return super.touchesEnded(touches, with: event)
        }

        if let targetActionView = targetActionView(at: point) {
            didTapTargetActionView?(targetActionView)
            return
        }

        super.touchesEnded(touches, with: event)
    }

    func targetActionView(at point: CGPoint) -> UIView? {
        targetActionViews.first { isTappableTargetActionView($0, at: point) }
    }
}

private extension UIView {
    /// Only the visible part counts: a target scrolled under a bar must not turn a tap on that bar into its action.
    func isTappableTargetActionView(_ view: UIView, at point: CGPoint) -> Bool {
        guard
            let window,
            view.window === window,
            !view.isHidden,
            view.alpha > 0.01,
            let visibleFrame = view.hintVisibleFrame(in: window)
        else {
            return false
        }

        return convert(visibleFrame, from: window).contains(point)
    }
}

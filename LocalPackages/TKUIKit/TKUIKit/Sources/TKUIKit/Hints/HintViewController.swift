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
        view.addSubview(dismissControl)

        contentLayoutTracker.onSourceViewLost = { [weak self] in
            self?.didLoseSourceView?()
        }

        dismissControl.addTarget(self, action: #selector(didTapDismissControl(_:)), for: .touchUpInside)
        dismissControl.didTapTargetActionView = { [weak self] view in
            guard let self else { return }
            if let control = view as? UIControl {
                control.sendActions(for: .touchUpInside)
                control.sendActions(for: .primaryActionTriggered)
                didTapTargetActionView?()
                return
            }
            didTapTargetActionView?()
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
        hintView.targetActionViews = targetActionViews
        dismissControl.targetActionViews = targetActionViews

        let contentViewControllerToResolvePosition = contentViewControllerProvider(nil)

        let (contentFrame, resolvedPosition) = contentLayoutTracker.resolveLayout(
            sourceView: sourceView,
            sourceWindow: sourceWindow,
            configuration: configuration,
            contentViewController: contentViewControllerToResolvePosition
        )

        let contentViewController = contentViewControllerProvider(resolvedPosition.direction)
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
        contentViewController.view.alpha = 0

        contentLayoutTracker.install(
            contentViewController: contentViewController,
            in: view,
            sourceView: sourceView,
            sourceWindow: sourceWindow,
            configuration: configuration,
            resolvedPosition: resolvedPosition,
            initialFrame: contentFrame
        )
        view.layoutIfNeeded()

        hintResolvedPayload = (resolvedPosition, configuration.animationStyle)
        contentViewController.view.layoutIfNeeded()

        let animator: HintAnimator
        switch configuration.animationStyle {
        case .bouncing:
            animator = BouncingHintAnimator()
        }
        animator.show(view: contentViewController.view, for: resolvedPosition, completion: {})
    }

    func hideHint(completion: @escaping () -> Void) {
        contentLayoutTracker.reset()
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
            contentViewController.willMove(toParent: nil)
            contentViewController.view.removeFromSuperview()
            contentViewController.removeFromParent()
            self.contentViewController = nil
            self.hintResolvedPayload = nil
            self.clearTargetActionViews()
            completion()
        }
    }

    func removeHint() {
        contentLayoutTracker.reset()
        contentViewController?.willMove(toParent: nil)
        contentViewController?.view.removeFromSuperview()
        contentViewController?.removeFromParent()
        contentViewController = nil
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
}

private extension HintViewController {
    func clearTargetActionViews() {
        hintView.targetActionViews = []
        dismissControl.targetActionViews = []
    }
}

private final class HintContainerView: UIView {
    var targetActionViews = [UIView]()

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        guard hitView === self, shouldBypassForTargetActionView(point) else {
            return hitView
        }
        return nil
    }

    private func shouldBypassForTargetActionView(_ point: CGPoint) -> Bool {
        targetActionViews.contains { view in
            guard
                view.window === window,
                !view.isHidden,
                view.alpha > 0.01
            else {
                return false
            }

            return view.convert(view.bounds, to: self).contains(point)
        }
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

    private func targetActionView(at point: CGPoint) -> UIView? {
        targetActionViews.first { view in
            guard
                view.window === window,
                !view.isHidden,
                view.alpha > 0.01
            else {
                return false
            }

            return view.convert(view.bounds, to: self).contains(point)
        }
    }
}

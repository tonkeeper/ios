import TKUIKit
import UIKit

public final class StoriesPresentationController: UIPresentationController {
    public var didDismiss: (() -> Void)?

    let dimmingView: TKPassthroughView = {
        let view = TKPassthroughView()
        view.backgroundColor = .black
        view.alpha = 0.0
        return view
    }()

    private lazy var gesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureHandler(_:)))

    override init(
        presentedViewController: UIViewController,
        presenting presentingViewController: UIViewController?
    ) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

    override public func presentationTransitionWillBegin() {
        guard let containerView else { return }
        containerView.insertSubview(dimmingView, at: 0)

        setupPanGesture()

        dimmingView.snp.makeConstraints { make in
            make.edges.equalTo(containerView)
        }

        guard let coordinator = presentedViewController.transitionCoordinator else {
            dimmingView.alpha = .dimmingViewPresentedAlpha
            return
        }
        coordinator.animate { _ in
            self.dimmingView.alpha = .dimmingViewPresentedAlpha
        }
    }

    override public func dismissalTransitionWillBegin() {
        guard let coordinator = presentedViewController.transitionCoordinator else {
            dimmingView.alpha = 0.0
            return
        }
        coordinator.animate { _ in
            self.dimmingView.alpha = 0.0
        }
    }

    override public func dismissalTransitionDidEnd(_ completed: Bool) {
        guard completed else { return }
        didDismiss?()
    }

    override public func containerViewWillLayoutSubviews() {
        presentedView?.frame = frameOfPresentedViewInContainerView
    }

    override public var frameOfPresentedViewInContainerView: CGRect {
        containerView?.bounds ?? .zero
    }

    private func setupPanGesture() {
        gesture.delegate = self
        containerView?.addGestureRecognizer(gesture)
    }

    @objc
    private func panGestureHandler(_ gesture: UIPanGestureRecognizer) {
        guard let containerView else { return }
        let containerViewFrame = containerView.frame
        let translation = gesture.translation(in: containerView)
        let velocity = gesture.velocity(in: containerView)
        let progress = translation.y / containerViewFrame.height
        let offset = max(translation.y, 0)

        switch gesture.state {
        case .changed:
            updatePresentedViewOriginY(offset, animated: false)
            updateDimmingViewAlpha(.dimmingViewPresentedAlpha - progress, animated: false)
        case .failed, .cancelled:
            updatePresentedViewOriginY(0, animated: true)
            updateDimmingViewAlpha(.dimmingViewPresentedAlpha, animated: true)
        case .ended:
            if progress > 0.5 || velocity.y > 900 {
                presentedViewController.dismiss(animated: true)
            } else {
                updatePresentedViewOriginY(0, animated: true)
                updateDimmingViewAlpha(.dimmingViewPresentedAlpha, animated: true)
            }
        default: break
        }
    }

    private func updatePresentedViewOriginY(_ originY: CGFloat, animated: Bool) {
        guard animated else {
            presentedView?.frame.origin.y = originY
            return
        }
        let animator = UIViewPropertyAnimator(duration: 0.2, dampingRatio: 1.0)
        animator.addAnimations {
            self.presentedView?.frame.origin.y = originY
        }
        animator.startAnimation()
    }

    private func updateDimmingViewAlpha(_ alpha: CGFloat, animated: Bool) {
        guard animated else {
            dimmingView.alpha = alpha
            return
        }
        let animator = UIViewPropertyAnimator(duration: 0.2, dampingRatio: 1.0)
        animator.addAnimations {
            self.dimmingView.alpha = alpha
        }
        animator.startAnimation()
    }
}

extension StoriesPresentationController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        !presentedViewController.isModalInPresentation
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer == gesture else { return true }
        return false
    }
}

private extension CGFloat {
    static let dimmingViewPresentedAlpha: CGFloat = 0.85
}

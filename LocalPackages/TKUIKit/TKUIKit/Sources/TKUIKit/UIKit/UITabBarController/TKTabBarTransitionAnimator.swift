import UIKit

public final class TKTabBarTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    enum Direction: Equatable {
        case forward
        case backward

        init?(fromIndex: Int, toIndex: Int) {
            guard fromIndex != toIndex else { return nil }
            self = toIndex > fromIndex ? .forward : .backward
        }

        var incomingStartOffset: CGFloat {
            sign * .slideDistance
        }

        var outgoingEndOffset: CGFloat {
            -sign * .slideDistance
        }

        private var sign: CGFloat {
            switch self {
            case .forward: 1
            case .backward: -1
            }
        }
    }

    let direction: Direction

    public init?(fromIndex: Int, toIndex: Int) {
        guard let direction = Direction(fromIndex: fromIndex, toIndex: toIndex) else { return nil }
        self.direction = direction
        super.init()
    }

    public func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        .tabSwitchDuration
    }

    public func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
              let toView = transitionContext.view(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        let fromView = transitionContext.view(forKey: .from)

        // The outgoing view keeps the top slot: tab backgrounds are opaque, so the incoming
        // one shows through as the fade progresses instead of covering it at half opacity.
        if let fromView, fromView.superview === containerView {
            containerView.insertSubview(toView, belowSubview: fromView)
        } else {
            containerView.addSubview(toView)
        }

        guard transitionContext.isAnimated, let fromView else {
            toView.frame = finalFrame
            transitionContext.completeTransition(true)
            return
        }

        let fromViewFrame = fromView.frame
        toView.frame = finalFrame.offsetBy(dx: direction.incomingStartOffset, dy: 0)
        toView.alpha = 0

        let animator = UIViewPropertyAnimator(
            duration: transitionDuration(using: transitionContext),
            curve: .easeOut
        ) { [direction] in
            toView.frame = finalFrame
            toView.alpha = 1
            fromView.frame = fromViewFrame.offsetBy(dx: direction.outgoingEndOffset, dy: 0)
            fromView.alpha = 0
        }
        animator.addCompletion { _ in
            // UIKit shows this same view again on the next visit to its tab.
            fromView.frame = fromViewFrame
            fromView.alpha = 1
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        animator.startAnimation()
    }
}

private extension CGFloat {
    static let slideDistance: CGFloat = 32
}

private extension TimeInterval {
    static let tabSwitchDuration: TimeInterval = 0.1
}

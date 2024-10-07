import UIKit

final class StoriesPresentationAnimator: UIPercentDrivenInteractiveTransition {
  var animator: UIViewPropertyAnimator?
  
  var progress: CGFloat = 0
  var isPresentation: Bool = true
}

extension StoriesPresentationAnimator: UIViewControllerAnimatedTransitioning {
  func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
    0.45
  }
  
  func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
    let animator = transitionAnimator(context: transitionContext)
    animator.addCompletion { [weak self] _ in
      self?.animator = nil
    }
    self.animator = animator
    animator.startAnimation()
  }
  
  private func transitionAnimator(context: UIViewControllerContextTransitioning) -> UIViewPropertyAnimator {
    let duration = transitionDuration(using: context)
    let containerView = context.containerView
    guard let view = context.view(forKey: isPresentation ? .to : .from),
          let viewController = context.viewController(forKey: isPresentation ? .to : .from) else {
      return UIViewPropertyAnimator()
    }
    
    if isPresentation {
      containerView.addSubview(view)
    }
    
    let presentedFrame = context.finalFrame(for: viewController)
    var dismissedFrame = presentedFrame
    dismissedFrame.origin.y = context.containerView.bounds.height
    
    let initialFrame = isPresentation ? dismissedFrame : presentedFrame
    let finalFrame = isPresentation ? presentedFrame : dismissedFrame
    
    view.frame = initialFrame
    let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.5)
    animator.addAnimations {
      view.frame = finalFrame
    }
    animator.addCompletion { position in
      switch position {
      case .end:
        context.completeTransition(!context.transitionWasCancelled)
      default:
        context.completeTransition(false)
      }
    }
    animator.isUserInteractionEnabled = true
    return animator
  }
  
  func interruptibleAnimator(using transitionContext: any UIViewControllerContextTransitioning) -> any UIViewImplicitlyAnimating {
    if let animator {
      return animator
    } else {
      let animator = transitionAnimator(context: transitionContext)
      animator.addCompletion { [weak self] _ in
        self?.animator = nil
      }
      self.animator = animator
      return animator
    }
  }
}

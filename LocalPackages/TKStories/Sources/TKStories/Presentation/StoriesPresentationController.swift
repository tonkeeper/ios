import UIKit
import TKUIKit

final class StoriesPresentationController: UIPresentationController {
 
  let dimmingView: TKPassthroughView = {
    let view = TKPassthroughView()
    view.backgroundColor = .black
    view.alpha = 0.0
    return view
  }()
  
  private lazy var gesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureHandler(_:)))
  
  private let animationController: StoriesPresentationAnimator
  
  init(presentedViewController: UIViewController,
                presenting presentingViewController: UIViewController?,
                animationController: StoriesPresentationAnimator) {
    self.animationController = animationController
    super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
  }
  
  override func presentationTransitionWillBegin() {
    guard let containerView else { return }
    containerView.insertSubview(dimmingView, at: 0)
    
    setupPanGesture()
    
    presentedView?.layer.cornerRadius = 20
    presentedView?.layer.masksToBounds = true
    
    dimmingView.snp.makeConstraints { make in
      make.edges.equalTo(containerView)
    }
    
    guard let coordinator = presentedViewController.transitionCoordinator else {
      dimmingView.alpha = 1.0
      return
    }
    coordinator.animate { _ in
      self.dimmingView.alpha = 1.0
    }
  }
  
  override func dismissalTransitionWillBegin() {
    guard let coordinator = presentedViewController.transitionCoordinator else {
      dimmingView.alpha = 0.0
      return
    }
    coordinator.animate { _ in
      self.dimmingView.alpha = 0.0
    }
  }
  
  override func containerViewWillLayoutSubviews() {
    presentedView?.frame = frameOfPresentedViewInContainerView
  }

  override var frameOfPresentedViewInContainerView: CGRect {
    guard let containerView else { return .zero }
    let frame = CGRect(
      origin: CGPoint(x: 0, y: containerView.safeAreaInsets.top),
      size: CGSize(width: containerView.bounds.width, height: containerView.bounds.height - containerView.safeAreaInsets.top - containerView.safeAreaInsets.bottom)
    )
    return frame
  }
  
  
  private func setupPanGesture() {
    gesture.delegate = self
    containerView?.addGestureRecognizer(gesture)
  }
  
  @objc
  private func panGestureHandler(_ gesture: UIPanGestureRecognizer) {
    guard let containerView else { return }
    let containerViewFrame = containerView.frame
    switch gesture.state {
    case .began:
      animationController.wantsInteractiveStart = true
      presentedViewController.dismiss(animated: true)
    case .changed:
      let translation = gesture.translation(in: containerView)
      let progress = translation.y / containerViewFrame.height
      animationController.update(progress)
    case .ended, .cancelled, .failed:
      animationController.wantsInteractiveStart = false
      let translation = gesture.translation(in: containerView)
      let progress = translation.y / containerViewFrame.height
      if progress > 0.5 {
        animationController.finish()
      } else {
        animationController.cancel()
      }
    default:
      break
    }
  }
}

extension StoriesPresentationController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer == gesture else { return true }
    return false
  }
}

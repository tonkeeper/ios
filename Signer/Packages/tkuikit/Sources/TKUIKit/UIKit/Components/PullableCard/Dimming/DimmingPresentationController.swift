import UIKit

final class DimmingPresentationController: UIPresentationController {
  
  private let dimmingView = DimmingView()
  
  override func presentationTransitionWillBegin() {
    super.presentationTransitionWillBegin()
    setupDimmingView()
    containerView?.layoutIfNeeded()
    dimmingView.prepareForPresentationTransition()
    presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [dimmingView] _ in
      dimmingView.performPresentationTransition()
    })
  }
  
  override func dismissalTransitionWillBegin() {
    super.dismissalTransitionWillBegin()
    dimmingView.prepareForDimissalTransition()
    presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [dimmingView] _ in
      dimmingView.performDismissalTransition()
    })
  }
  
  override func dismissalTransitionDidEnd(_ completed: Bool) {
    super.dismissalTransitionDidEnd(completed)
    delegate?.presentationControllerDidDismiss?(self)
  }
  
  override func containerViewDidLayoutSubviews() {
    super.containerViewDidLayoutSubviews()
    dimmingView.frame = containerView?.bounds ?? .zero
    presentedView?.frame = containerView?.bounds ?? .zero
  }
}

private extension DimmingPresentationController {
  func setupDimmingView() {
    containerView?.addSubview(dimmingView)
    
    let tapGesture = UITapGestureRecognizer(target: self,
                                            action: #selector(didTap))
    dimmingView.addGestureRecognizer(tapGesture)
  }
  
  @objc
  func didTap() {
    presentingViewController.dismiss(animated: true)
  }
}

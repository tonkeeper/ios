import UIKit

final class StoriesModalTransitionManager: NSObject, UIViewControllerTransitioningDelegate {

  private let animationController = StoriesPresentationAnimator()
  
  func presentationController(forPresented presented: UIViewController,
                              presenting: UIViewController?,
                              source: UIViewController) -> UIPresentationController? {
    StoriesPresentationController(
      presentedViewController: presented,
      presenting: presenting,
      animationController: animationController
    )
  }
  
  func animationController(forPresented presented: UIViewController,
                           presenting: UIViewController,
                           source: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
    animationController.wantsInteractiveStart = false
    animationController.isPresentation = true
    return animationController
  }
  
  func animationController(forDismissed dismissed: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
    animationController.isPresentation = false
    return animationController
  }
  
  func interactionControllerForDismissal(using animator: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
    animationController.isPresentation = false
    return animationController
  }
}

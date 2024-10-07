import UIKit

final class StoriesModalTransitionManager: NSObject, UIViewControllerTransitioningDelegate {

  func presentationController(forPresented presented: UIViewController,
                              presenting: UIViewController?,
                              source: UIViewController) -> UIPresentationController? {
    StoriesPresentationController(
      presentedViewController: presented,
      presenting: presenting
    )
  }
  
  func animationController(forPresented presented: UIViewController,
                           presenting: UIViewController,
                           source: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
    let animationController = StoriesPresentationAnimator()
    animationController.isPresentation = true
    return animationController
  }
  
  func animationController(forDismissed dismissed: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
    let animationController = StoriesPresentationAnimator()
    animationController.isPresentation = false
    return animationController
  }
}

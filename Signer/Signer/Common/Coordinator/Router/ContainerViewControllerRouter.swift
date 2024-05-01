import UIKit

class ContainerViewControllerRouter<RootViewController: UIViewController>: NSObject, UIAdaptivePresentationControllerDelegate {
  private var onDismiss: (() -> Void)?
  
  let rootViewController: RootViewController
  init(rootViewController: RootViewController) {
    self.rootViewController = rootViewController
  }
  
  func present(_ viewController: UIViewController,
               animated: Bool = true,
               completion: (() -> Void)? = nil,
               onDismiss: (() -> Void)? = nil) {
    self.onDismiss = onDismiss
    viewController.presentationController?.delegate = self
    rootViewController.present(viewController,
                               animated: animated,
                               completion: completion)
  }
  
  func dismiss(animated: Bool = true,
               completion: (() -> Void)? = nil) {
    rootViewController.dismiss(animated: animated,
                               completion: completion)
  }
  
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    onDismiss?()
  }
}

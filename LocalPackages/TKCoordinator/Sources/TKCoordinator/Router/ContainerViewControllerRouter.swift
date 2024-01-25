import UIKit

public class ContainerViewControllerRouter<RootViewController: UIViewController>: NSObject, Router, UIAdaptivePresentationControllerDelegate {
  private var onDismiss: (() -> Void)?
  
  public let rootViewController: RootViewController
  public init(rootViewController: RootViewController) {
    self.rootViewController = rootViewController
  }
  
  public func present(_ viewController: UIViewController,
                      animated: Bool = true,
                      completion: (() -> Void)? = nil,
                      onDismiss: (() -> Void)? = nil) {
    self.onDismiss = onDismiss
    viewController.presentationController?.delegate = self
    rootViewController.present(viewController,
                               animated: animated,
                               completion: completion)
  }
  
  public func dismiss(animated: Bool = true,
                      completion: (() -> Void)? = nil) {
    rootViewController.dismiss(animated: animated,
                               completion: completion)
  }
  
  public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    onDismiss?()
  }
}

import UIKit

extension UIViewController {

  func topPresentedViewController() -> UIViewController {
    guard let presented = self.presentedViewController else {
      return self
    }
    return presented.topPresentedViewController()
  }
}

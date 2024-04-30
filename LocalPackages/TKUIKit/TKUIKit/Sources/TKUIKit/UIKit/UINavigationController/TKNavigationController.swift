import UIKit

public final class TKNavigationController: UINavigationController {
  
  public var interactivePopGestureEnabled = true {
    didSet {
      interactivePopGestureRecognizer?.isEnabled = interactivePopGestureEnabled
    }
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    interactivePopGestureRecognizer?.delegate = self
    interactivePopGestureRecognizer?.isEnabled = interactivePopGestureEnabled
  }
}

extension TKNavigationController: UIGestureRecognizerDelegate {
  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                         shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let view = gestureRecognizer.view,
          let otherView = otherGestureRecognizer.view else { return false }
    
    guard otherView.next is TKNavigationController,
          otherView.isDescendant(of: view) else {
      return true
    }
    return false
  }
}

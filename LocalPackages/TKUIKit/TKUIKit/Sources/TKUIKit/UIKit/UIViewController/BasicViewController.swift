import UIKit

open class BasicViewController: UIViewController {
  
  open override var preferredStatusBarStyle: UIStatusBarStyle {
    TKThemeManager.shared.theme.themeAppaearance.statusBarStyle(for: traitCollection.userInterfaceStyle)
  }

  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    navigationController?.fixInteractivePopGestureRecognizer(delegate: self)
  }
}

extension BasicViewController: UIGestureRecognizerDelegate {
  public func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      otherGestureRecognizer is PanDirectionGestureRecognizer
    }
}

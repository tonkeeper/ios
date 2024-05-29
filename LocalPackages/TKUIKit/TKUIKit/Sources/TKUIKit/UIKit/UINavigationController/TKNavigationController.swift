import UIKit

public final class TKNavigationController: UINavigationController {
  
  public override var preferredStatusBarStyle: UIStatusBarStyle {
    TKThemeManager.shared.theme.themeAppaearance.statusBarStyle(for: traitCollection.userInterfaceStyle)
  }
}

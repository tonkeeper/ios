import UIKit

public final class TKNavigationController: UINavigationController {
  
  private let gradientView = TKGradientView(color: .Background.page, direction: .topToBottom)
  
  public override var preferredStatusBarStyle: UIStatusBarStyle {
    TKThemeManager.shared.theme.themeAppaearance.statusBarStyle(for: traitCollection.userInterfaceStyle)
  }

  public override init(rootViewController: UIViewController) {
    super.init(rootViewController: rootViewController)
    setup()
  }
  
  public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    setup()
  }
  
  public init() {
    super.init(nibName: nil, bundle: nil)
    setup()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension TKNavigationController {
  func setup() {
    view.insertSubview(gradientView, belowSubview: navigationBar)
    gradientView.snp.makeConstraints { make in
      make.top.left.right.equalTo(view)
      make.bottom.equalTo(navigationBar)
    }
  }
}

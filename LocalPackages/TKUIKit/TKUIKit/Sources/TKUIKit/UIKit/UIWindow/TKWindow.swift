import UIKit

open class TKWindow: UIWindow {
  
  private var token: NSObjectProtocol?
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  public override init(windowScene: UIWindowScene) {
    super.init(windowScene: windowScene)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    token = nil
  }
}

private extension TKWindow {
  func setup() {
//    overrideUserInterfaceStyle = ThemeManager.shared.theme.userInterfaceStyle
    token = NotificationCenter.default.addObserver(
      forName: Notification.Name.didChangeThemeMode,
      object: nil,
      queue: .main,
      using: { [weak self] notification in
//        self?.overrideUserInterfaceStyle = ThemeManager.shared.theme.userInterfaceStyle
      }
    )
  }
}


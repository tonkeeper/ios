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
    TKThemeManager.shared.addEventObserver(self) { observer, theme in
      observer.updateUserInterfaceStyle(theme.themeAppaearance.userInterfaceStyle)
    }
    updateUserInterfaceStyle(TKThemeManager.shared.themeAppearance.userInterfaceStyle)
  }
  
  private func updateUserInterfaceStyle(_ userInterfaceStyle: UIUserInterfaceStyle) {
    if traitCollection.userInterfaceStyle == userInterfaceStyle {
      if traitCollection.userInterfaceStyle == .light {
        overrideUserInterfaceStyle = .dark
      } else {
        overrideUserInterfaceStyle = .light
      }
    }
    overrideUserInterfaceStyle = userInterfaceStyle
  }
}


import Foundation
import TKUIKit

public final class AppSettings {
  private let userDefaults: UserDefaults
  
  init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
  }
  
  public func isBuySellItemMarkedDoNotShowWarning(_ buySellItemId: String) -> Bool {
    let key = String.buySellItemDoNotShowKey + "_\(buySellItemId)"
    return userDefaults.bool(forKey: key)
  }
  
  public func setIsBuySellItemMarkedDoNotShowWarning(_ buySellItemId: String, doNotShow: Bool) {
    let key = String.buySellItemDoNotShowKey + "_\(buySellItemId)"
    userDefaults.set(doNotShow, forKey: key)
  }
  
  public func themeMode() -> ThemeMode {
    guard let value = userDefaults.value(forKey: .themeModeKey) as? String,
          let themeMode = ThemeMode(rawValue: value) else { return .blue }
    return themeMode
  }
  
  public func setThemeMode(_ themeMode: ThemeMode) {
    userDefaults.set(themeMode.rawValue, forKey: .themeModeKey)
  }
}

private extension String {
  static let buySellItemDoNotShowKey = "buy_sell_item_do_not_show_warning"
  static let themeModeKey = "theme_mode"
}

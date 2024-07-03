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
  
  public var isSecureMode: Bool {
    get {
      userDefaults.bool(forKey: .isSecureModeKey)
    }
    set {
      userDefaults.setValue(newValue, forKey: .isSecureModeKey)
    }
  }
}

private extension String {
  static let buySellItemDoNotShowKey = "buy_sell_item_do_not_show_warning"
  static let isSecureModeKey = "is_secure_mode"
}

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

  public var isDecryptCommentWarningDoNotShow: Bool {
    get {
      userDefaults.bool(forKey: .decryptCommentDoNotShowKey)
    }
    set {
      userDefaults.setValue(newValue, forKey: .decryptCommentDoNotShowKey)
    }
  }
  
  public var isSecureMode: Bool {
    get {
      userDefaults.bool(forKey: .isSecureModeKey)
    }
    set {
      userDefaults.setValue(newValue, forKey: .isSecureModeKey)
    }
  }
  
  public var installDeviceID: String {
    if let deviceId = userDefaults.string(forKey: .installDeviceId) {
      return deviceId
    } else {
      let deviceID = UUID()
      userDefaults.set(deviceID.uuidString, forKey: .installDeviceId)
      return deviceID.uuidString
    }
  }
  
  public var fcmToken: String? {
    get {
      userDefaults.string(forKey: .fcmToken)
    }
    set {
      userDefaults.setValue(newValue, forKey: .fcmToken)
    }
  }
  
  public var addressCopyCount: Int {
    get {
      userDefaults.integer(forKey: .addressCopyCount)
    }
    set {
      userDefaults.setValue(newValue, forKey: .addressCopyCount)
    }
  }
}

private extension String {
  static let buySellItemDoNotShowKey = "buy_sell_item_do_not_show_warning"
  static let decryptCommentDoNotShowKey = "decrypt_comment_do_not_show_warning"
  static let isSecureModeKey = "is_secure_mode"
  static let selectedCountryCode = "selected_country_code"
  static let installDeviceId = "install_device_id"
  static let fcmToken = "fcm_token"
  static let addressCopyCount = "address_copy_count"
}

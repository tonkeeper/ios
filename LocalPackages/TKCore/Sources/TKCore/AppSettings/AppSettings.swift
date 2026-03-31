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

    public func isDappOpenWarningDoNotShow(_ host: String) -> Bool {
        let key = String.dappOpenWarningDoNotShowKey + "_\(host)"
        return userDefaults.bool(forKey: key)
    }

    public func setIsDappOpenWarningDoNotShow(_ host: String, doNotShow: Bool) {
        let key = String.dappOpenWarningDoNotShowKey + "_\(host)"
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

    public var firstLaunchDate: Date? {
        get {
            guard let timestamp = userDefaults.value(forKey: .firstLaunchTimestamp) as? TimeInterval else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            userDefaults.setValue(newValue?.timeIntervalSince1970, forKey: .firstLaunchTimestamp)
        }
    }

    public var isSupportPopUpShown: Bool {
        get {
            userDefaults.bool(forKey: .supportPopUpShownKey)
        }
        set {
            userDefaults.setValue(newValue, forKey: .supportPopUpShownKey)
        }
    }

    public let dappHostWhiteList: [String] = ["dapp.aeon.xyz"]
}

private extension String {
    static let buySellItemDoNotShowKey = "buy_sell_item_do_not_show_warning"
    static let dappOpenWarningDoNotShowKey = "dapp_open_warning_do_not_show_key"
    static let decryptCommentDoNotShowKey = "decrypt_comment_do_not_show_warning"
    static let isSecureModeKey = "is_secure_mode"
    static let selectedCountryCode = "selected_country_code"
    static let fcmToken = "fcm_token"
    static let addressCopyCount = "address_copy_count"
    static let didMigrateTonConnectAppVaultKey = "did_migrate_ton_connect_apps_vault"
    static let firstLaunchTimestamp = "first_launch_timestamp"
    static let supportPopUpShownKey = "support_popup_shown_key"
}

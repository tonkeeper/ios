import Foundation
import KeeperCore
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

    public var fcmToken: String? {
        get {
            userDefaults.string(forKey: .fcmToken)
        }
        set {
            userDefaults.setValue(newValue, forKey: .fcmToken)
        }
    }

    /// Last multichain push state accepted by the backend: the token and the full wallet id
    /// set. `nil` wallet ids means "never synced", so a device that has no notifications on
    /// never has to authenticate just to send an empty subscription.
    public var multichainPushToken: String? {
        get {
            userDefaults.string(forKey: .multichainPushToken)
        }
        set {
            userDefaults.setValue(newValue, forKey: .multichainPushToken)
        }
    }

    /// Device the push subscription below belongs to: a rotated device id invalidates it.
    public var multichainPushDeviceId: String? {
        get {
            userDefaults.string(forKey: .multichainPushDeviceId)
        }
        set {
            userDefaults.setValue(newValue, forKey: .multichainPushDeviceId)
        }
    }

    public var multichainPushWalletIds: [String]? {
        get {
            userDefaults.stringArray(forKey: .multichainPushWalletIds)
        }
        set {
            userDefaults.setValue(newValue, forKey: .multichainPushWalletIds)
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

    public let dappHostWhiteList: [String] = ["dapp.aeon.xyz"]
}

private extension String {
    static let buySellItemDoNotShowKey = "buy_sell_item_do_not_show_warning"
    static let dappOpenWarningDoNotShowKey = "dapp_open_warning_do_not_show_key"
    static let decryptCommentDoNotShowKey = "decrypt_comment_do_not_show_warning"
    static let fcmToken = "fcm_token"
    static let multichainPushToken = "multichain_push_token"
    static let multichainPushDeviceId = "multichain_push_device_id"
    static let multichainPushWalletIds = "multichain_push_wallet_ids"
    static let addressCopyCount = "address_copy_count"
    static let firstLaunchTimestamp = "first_launch_timestamp"
}

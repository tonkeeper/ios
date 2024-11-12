import Foundation
import TonSwift
import TKLocalize

public struct Wallet: Codable, Hashable {
  
  public let id: String
  
  /// Unique internal ID for this wallet
  public let identity: WalletIdentity
  
  // Wallet's metadata as human-readable label, color, emoji etc
  public var metaData: WalletMetaData
  
  public var setupSettings: WalletSetupSettings
  
  /// Per-wallet notifications: maybe filters by assets, amounts, dapps etc.
  public let notificationSettings: NotificationSettings
  
  /// Backup settings for this wallet.
  public let backupSettings: WalletBackupSettings
  
  /// List of remembered favorite addresses
  let addressBook: [AddressBookEntry]
  
  public let batterySettings: BatterySettings
  
  /// Store your app-specific configuration here. Such as theme settings and other preferences.
  /// TODO: make this codeable so it can be backed up and sycned.
  //    let userInfo: [String:AnyObject]
  
  /// If the wallet has potential sibling wallets, these are enumerated here.
  /// If the list has zero or 1 item, then UI should allow set `preferredVersion`
  func availableWalletVersions() -> [WalletContractVersion] {
    return []
  }
  
  init(id: String,
       identity: WalletIdentity,
       metaData: WalletMetaData,
       setupSettings: WalletSetupSettings,
       notificationSettings: NotificationSettings = NotificationSettings(isOn: false, dapps: [:]),
       backupSettings: WalletBackupSettings = .init(enabled: true, revision: 1, voucher: nil),
       addressBook: [AddressBookEntry] = [],
       batterySettings: BatterySettings) {
    self.id = id
    self.identity = identity
    self.metaData = metaData
    self.setupSettings = setupSettings
    self.notificationSettings = notificationSettings
    self.backupSettings = backupSettings
    self.addressBook = addressBook
    self.batterySettings = batterySettings
  }
  
  public static func == (lhs: Wallet, rhs: Wallet) -> Bool {
    lhs.id == rhs.id
  }
  
  public func isIdentityEqual(wallet: Wallet) -> Bool {
    self.identity == wallet.identity
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.identity = try container.decode(WalletIdentity.self, forKey: .identity)
    self.metaData = try container.decode(WalletMetaData.self, forKey: .metaData)
    self.setupSettings = try container.decode(WalletSetupSettings.self, forKey: .setupSettings)
    self.notificationSettings = try container.decode(NotificationSettings.self, forKey: .notificationSettings)
    self.backupSettings = try container.decode(WalletBackupSettings.self, forKey: .backupSettings)
    self.addressBook = try container.decode([AddressBookEntry].self, forKey: .addressBook)
    self.batterySettings = try container.decodeIfPresent(BatterySettings.self, forKey: .batterySettings) ?? BatterySettings()
  }
}

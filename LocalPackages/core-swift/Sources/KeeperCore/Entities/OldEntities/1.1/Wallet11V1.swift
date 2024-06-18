import Foundation
import TonSwift
import TKLocalize

extension Version11V1 {
  public struct Wallet: Codable, Hashable, Identifiable {
    /// Unique internal ID for this wallet
    public let identity: Version11V1.WalletIdentity
    
    // Wallet's metadata as human-readable label, color, emoji etc
    public let metaData: WalletMetaData
    
    public let setupSettings: WalletSetupSettings
    
    /// Per-wallet notifications: maybe filters by assets, amounts, dapps etc.
    let notificationSettings: NotificationSettings
    
    /// Backup settings for this wallet.
    public let backupSettings: WalletBackupSettings
    
    /// List of remembered favorite addresses
    let addressBook: [AddressBookEntry]
    
    /// Store your app-specific configuration here. Such as theme settings and other preferences.
    /// TODO: make this codeable so it can be backed up and sycned.
    //    let userInfo: [String:AnyObject]
    
    /// If the wallet has potential sibling wallets, these are enumerated here.
    /// If the list has zero or 1 item, then UI should allow set `preferredVersion`
    func availableWalletVersions() -> [WalletContractVersion] {
      return []
    }
    
    init(identity: Version11V1.WalletIdentity,
         metaData: WalletMetaData,
         setupSettings: WalletSetupSettings,
         notificationSettings: NotificationSettings = .init(),
         backupSettings: WalletBackupSettings = .init(enabled: true, revision: 1, voucher: nil),
         addressBook: [AddressBookEntry] = []) {
      self.identity = identity
      self.metaData = metaData
      self.setupSettings = setupSettings
      self.notificationSettings = notificationSettings
      self.backupSettings = backupSettings
      self.addressBook = addressBook
    }
    
    public static func == (lhs: Version11V1.Wallet, rhs: Version11V1.Wallet) -> Bool {
      lhs.identity == rhs.identity
    }
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(try? identity.identifier())
    }
    
    public var id: String {
      identity.id
    }
    
    public var tag: String? {
      switch identity.kind {
      case .Regular:
        return isTestnet ? "TESTNET" : nil
      case .Lockup:
        return nil
      case .Watchonly:
        return TKLocales.WalletTags.watch_only
      case .External:
        return "Signer"
      }
    }
  }
}

extension Version11V1.Wallet {
  enum Error: Swift.Error {
    case notAvailableWalletKind
    case notAvailableWalletRevision
  }
  
  public var publicKey: TonSwift.PublicKey {
    get throws {
      switch identity.kind {
      case let .Regular(publicKey, _):
        return publicKey
      case let .External(publicKey, _):
        return publicKey
      default:
        throw Error.notAvailableWalletKind
      }
    }
  }
  
  public var contract: WalletContract {
    get throws {
      let publicKey: TonSwift.PublicKey
      let contractVersion: WalletContractVersion
      switch identity.kind {
      case .Regular(let pk, let cv):
        publicKey = pk
        contractVersion = cv
      case .External(let pk, let cv):
        publicKey = pk
        contractVersion = cv
      default:
        throw Error.notAvailableWalletKind
      }
      
      switch contractVersion {
      case .v4R2:
        return WalletV4R2(publicKey: publicKey.data)
      case .v4R1:
        return WalletV4R1(publicKey: publicKey.data)
      case .v3R2:
        return try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r2)
      case .v3R1:
        return try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r1)
      }
    }
  }
  
  public var stateInit: StateInit {
    get throws {
      try contract.stateInit
    }
  }
  
  public var address: Address {
    get throws {
      switch identity.kind {
      case .Regular, .External:
        return try contract.address()
      case .Watchonly(let address):
        switch address {
        case .Resolved(let address):
          return address
        case .Domain(_, let address):
          return address
        }
      case .Lockup:
        throw Error.notAvailableWalletKind
      }
    }
  }
  
  public var friendlyAddress: FriendlyAddress {
    get throws {
      let isTestnet = self.isTestnet
      switch identity.kind {
      case .Regular, .External:
        return try contract.address().toFriendly(testOnly: isTestnet, bounceable: false)
      case .Watchonly(let address):
        switch address {
        case .Resolved(let address):
          return address.toFriendly(testOnly: isTestnet, bounceable: false)
        case .Domain(_, let address):
          return address.toFriendly(testOnly: isTestnet, bounceable: false)
        }
      case .Lockup:
        throw Error.notAvailableWalletKind
      }
    }
  }
  
  public var isRegular: Bool {
    guard case .Regular = identity.kind else {
      return false
    }
    return true
  }
  
  public var isExternal: Bool {
    guard case .External = identity.kind else {
      return false
    }
    return true
  }
  
  public var isWatchonly: Bool {
    guard case .Watchonly = identity.kind else {
      return false
    }
    return true
  }
  
  public var isTestnet: Bool {
    guard case .testnet = identity.network else {
      return false
    }
    return true
  }
  
  public var isTonconnectAvailable: Bool {
    isRegular || isTestnet
  }
}

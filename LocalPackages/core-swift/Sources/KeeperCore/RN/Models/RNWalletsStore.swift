import Foundation
import TonSwift

public struct RNWalletsStore: Codable {
  public let wallets: [RNWallet]
  public let selectedIdentifier: String
  public let biometryEnabled: Bool
  public let lockScreenEnabled: Bool
  
  enum CodingKeys: CodingKey {
    case wallets
    case selectedIdentifier
    case biometryEnabled
    case lockScreenEnabled
  }
  
  public init(wallets: [RNWallet],
              selectedIdentifier: String,
              biometryEnabled: Bool,
              lockScreenEnabled: Bool) {
    self.wallets = wallets
    self.selectedIdentifier = selectedIdentifier
    self.biometryEnabled = biometryEnabled
    self.lockScreenEnabled = lockScreenEnabled
  }
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.wallets = try container.decode([RNWallet].self, forKey: .wallets)
    self.selectedIdentifier = try container.decode(String.self, forKey: .selectedIdentifier)
    self.biometryEnabled = try container.decode(Bool.self, forKey: .biometryEnabled)
    self.lockScreenEnabled = try container.decodeIfPresent(Bool.self, forKey: .lockScreenEnabled) ?? false
  }
  
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(wallets, forKey: .wallets)
    try container.encode(selectedIdentifier, forKey: .selectedIdentifier)
    try container.encode(biometryEnabled, forKey: .biometryEnabled)
    try container.encodeIfPresent(lockScreenEnabled, forKey: .lockScreenEnabled)
  }
}

public struct RNWallet: Codable {
  
  enum Error: Swift.Error {
    case failedToCreateWallet
  }
  
  enum WalletType: String, Codable {
    case Regular
    case Lockup
    case WatchOnly
    case Signer
    case SignerDeeplink
    case Ledger
  }
  
  enum WalletNetwork: Int, Codable {
    case mainnet = -239
    case testnet = -3
  }
  
  enum RNContractVersion: String, Codable {
    case v5R1
    case v5Beta
    case v4R2
    case v4R1
    case v3R2
    case v3R1
    case LockupV1 = "lockup-0.1"
    
    init(walletContractVersion: WalletContractVersion) {
      switch walletContractVersion {
      case .v3R1:
        self = .v3R1
      case .v3R2:
        self = .v3R2
      case .v4R1:
        self = .v4R1
      case .v4R2:
        self = .v4R2
      case .v5Beta:
        self = .v5Beta
      case .v5R1:
        self = .v5R1
      }
    }
  }
  
  struct Ledger: Codable {
    let deviceId: String
    let deviceModel: String
    let accountIndex: Int16
  }
  
  let identifier: String
  let name: String
  let emoji: String
  let color: String
  let pubkey: String
  let network: WalletNetwork
  let type: WalletType
  let version: RNContractVersion
  let workchain: Int
  let ledger: Ledger?
}

public extension RNWallet {
  
  init(wallet: Wallet) {
    self.identifier = wallet.id
    self.name = wallet.label
    self.color = wallet.tintColor.rawValue
    self.network = {
      switch wallet.identity.network {
      case .mainnet:
        return .mainnet
      case .testnet:
        return .testnet
      }
    }()
    switch wallet.identity.kind {
    case .Regular(let publicKey, let walletContractVersion):
      self.type = .Regular
      self.pubkey = publicKey.data.hexString()
      self.version = RNContractVersion(walletContractVersion: walletContractVersion)
      self.ledger = nil
    case .Lockup(let publicKey, _):
      self.type = .Lockup
      self.pubkey = publicKey.data.hexString()
      self.version = .LockupV1
      self.ledger = nil
    case .Watchonly(_):
      self.type = .WatchOnly
      self.version = .v3R1
      self.ledger = nil
      self.pubkey = ""
    case .Signer(let publicKey, let walletContractVersion):
      self.type = .Signer
      self.pubkey = publicKey.data.hexString()
      self.version = RNContractVersion(walletContractVersion: walletContractVersion)
      self.ledger = nil
    case .SignerDevice(let publicKey, let walletContractVersion):
      self.type = .SignerDeeplink
      self.pubkey = publicKey.data.hexString()
      self.version = RNContractVersion(walletContractVersion: walletContractVersion)
      self.ledger = nil
    case .Ledger(let publicKey, let walletContractVersion, let ledgerDevice):
      self.type = .Ledger
      self.pubkey = publicKey.data.hexString()
      self.ledger = Ledger(deviceId: ledgerDevice.deviceId, deviceModel: ledgerDevice.deviceModel, accountIndex: ledgerDevice.accountIndex)
      self.version = RNContractVersion(walletContractVersion: walletContractVersion)
    }
    self.workchain = 0
    self.emoji = {
      switch wallet.icon {
      case .emoji(let emoji):
        return emoji
      case .icon(let image):
        return image.rnIconString
      }
    }()
    
  }
  
  func getWallet(backupDate: Date?) throws -> Wallet  {
    
    guard let publicKeyData = Data(hex: pubkey) else {
      throw Error.failedToCreateWallet
    }
    let publicKey = TonSwift.PublicKey(data: publicKeyData)
    
    let contractVersion: WalletContractVersion
    switch version {
    case .v3R1:
      contractVersion = .v3R1
    case .v3R2:
      contractVersion = .v3R2
    case .v4R1:
      contractVersion = .v4R1
    case .v4R2:
      contractVersion = .v4R2
    case .v5Beta:
      contractVersion = .v5Beta
    case .v5R1:
      contractVersion = .v5R1
    case .LockupV1:
      contractVersion = .v3R1
    }
    
    let network: Network
    switch self.network {
    case .mainnet:
      network = .mainnet
    case .testnet:
      network = .testnet
    }
    
    let contract: WalletContract
    switch contractVersion {
    case .v5R1:
      contract = WalletV5R1(
        publicKey: publicKey.data,
        walletId: WalletId(
          networkGlobalId: Int32(
            network.rawValue
          ),
          workchain: 0
        )
      )
    case .v5Beta:
      contract = WalletV5Beta(
        publicKey: publicKey.data,
        walletId: WalletIdBeta(
          networkGlobalId: Int32(
            network.rawValue
          ),
          workchain: 0
        )
      )
    case .v4R2:
      contract = WalletV4R2(publicKey: publicKey.data)
    case .v4R1:
      contract = WalletV4R1(publicKey: publicKey.data)
    case .v3R2:
      contract = try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r2)
    case .v3R1:
      contract = try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r1)
    }
    
    let kind: WalletKind
    switch type {
    case .Ledger:
      guard let ledgerDevice = ledger else {
        throw Error.failedToCreateWallet
      }
      kind = .Ledger(
        publicKey,
        contractVersion,
        Wallet.LedgerDevice(deviceId: ledgerDevice.deviceId,
                            deviceModel: ledgerDevice.deviceModel,
                            accountIndex: ledgerDevice.accountIndex)
      )
    case .Lockup:
      throw Error.failedToCreateWallet
    case .Regular:
      kind = .Regular(publicKey, contractVersion)
    case .Signer:
      kind = .Signer(publicKey, contractVersion)
    case .SignerDeeplink:
      kind = .SignerDevice(publicKey, contractVersion)
    case .WatchOnly:
      kind = .Watchonly(.Resolved(try contract.address()))
    }
    
    let icon: WalletIcon
    if emoji.count == 1 {
      icon = .emoji(emoji)
    } else {
      icon = .icon(WalletIcon.Image(rnIconString: emoji))
    }
    
    let tintColor = WalletTintColor(rawValue: color) ?? .defaultColor
    
    return Wallet(
      id: identifier,
      identity: WalletIdentity(network: network, kind: kind),
      metaData: WalletMetaData(label: name, tintColor: tintColor, icon: icon),
      setupSettings: WalletSetupSettings(backupDate: backupDate)
    )
  }
}

private extension WalletIcon.Image {
  var rnIconString: String {
    switch self {
    case .wallet:
      return "ic-wallet-32"
    case .leaf:
      return "ic-leaf-32"
    case .lock:
      return "ic-lock-32"
    case .key:
      return "ic-key-32"
    case .inbox:
      return "ic-inbox-32"
    case .snowflake:
      return "ic-snowflake-32"
    case .sparkles:
      return "ic-sparkles-32"
    case .sun:
      return "ic-sun-32"
    case .hare:
      return "ic-hare-32"
    case .flash:
      return "ic-flash-32"
    case .bankCard:
      return "ic-bank-card-32"
    case .gear:
      return "ic-gear-32"
    case .handRaised:
      return "ic-hand-raised-32"
    case .magnifyingGlassCircle:
      return "ic-magnifying-glass-circle-32"
    case .flashCircle:
      return "ic-flash-circle-32"
    case .dollarCircle:
      return "ic-dollar-circle-32"
    case .euroCircle:
      return "ic-euro-circle-32"
    case .sterlingCircle:
      return "ic-sterling-circle-32"
    case .yuanCircle:
      return "ic-chinese-yuan-circle-32"
    case .rubleCircle:
      return "ic-ruble-circle-32"
    case .indianRupeeCircle:
      return "ic-indian-rupee-circle-32"
    }
  }
  
  init(rnIconString: String) {
    switch rnIconString {
    case "ic-wallet-32":
      self = .wallet
    case "ic-leaf-32":
      self = .leaf
    case "ic-lock-32":
      self = .lock
    case "ic-key-32":
      self = .key
    case "ic-inbox-32":
      self = .inbox
    case "ic-snowflake-32":
      self = .snowflake
    case "ic-sparkles-32":
      self = .sparkles
    case "ic-sun-32":
      self = .sun
    case "ic-hare-32":
      self = .hare
    case "ic-flash-32":
      self = .flash
    case "ic-bank-card-32":
      self = .bankCard
    case "ic-gear-32":
      self = .gear
    case "ic-hand-raised-32":
      self = .handRaised
    case "ic-magnifying-glass-circle-32":
      self = .magnifyingGlassCircle
    case "ic-flash-circle-32":
      self = .flashCircle
    case "ic-dollar-circle-32":
      self = .dollarCircle
    case "ic-euro-circle-32":
      self = .euroCircle
    case "ic-sterling-circle-32":
      self = .sterlingCircle
    case "ic-chinese-yuan-circle-32":
      self = .yuanCircle
    case "ic-ruble-circle-32":
      self = .rubleCircle
    case "ic-indian-rupee-circle-32":
      self = .indianRupeeCircle
    default:
      self = .wallet
    }
  }
}

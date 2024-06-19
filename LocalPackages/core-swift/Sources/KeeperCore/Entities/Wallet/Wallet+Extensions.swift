import Foundation
import TonSwift

public extension Wallet {
  enum Error: Swift.Error {
    case invalidWalletKind
  }
  
  enum Kind {
    case regular
    case lockup
    case watchonly
    case signer
    case ledger
  }
  
  var kind: Kind {
    switch identity.kind {
    case .Regular:
      return .regular
    case .Lockup:
      return .lockup
    case .Watchonly:
      return .watchonly
    case .Signer:
      return .signer
    case .SignerDevice:
      return .signer
    case .Ledger:
      return .ledger
    }
  }
  
  var isTestnet: Bool {
    switch identity.network {
    case .testnet: return true
    case .mainnet: return false
    }
  }
  
  var publicKey: TonSwift.PublicKey {
    get throws {
      switch identity.kind {
      case .Regular(let publicKey, _):
        return publicKey
      case .Lockup(let publicKey, _):
        return publicKey
      case .Watchonly:
        throw Error.invalidWalletKind
      case .Signer(let publicKey, _):
        return publicKey
      case .SignerDevice(let publicKey, _):
        return publicKey
      case .Ledger(let publicKey, _, _):
        return publicKey
      }
    }
  }
  
  var contractVersion: WalletContractVersion {
    get throws {
      switch identity.kind {
      case .Regular(_, let contractVersion):
        return contractVersion
      case .Lockup(let publicKey, _):
        throw Error.invalidWalletKind
      case .Watchonly:
        throw Error.invalidWalletKind
      case .Signer(_, let contractVersion):
        return contractVersion
      case .SignerDevice(_, let contractVersion):
        return contractVersion
      case .Ledger(_, let contractVersion, _):
        return contractVersion
      }
    }
  }
  
  var contract: WalletContract {
    get throws {
      let publicKey = try publicKey
      let contractVersion = try contractVersion
      switch contractVersion {
      case .v3R1:
        return try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r1)
      case .v3R2:
        return try WalletV3(workchain: 0, publicKey: publicKey.data, revision: .r2)
      case .v4R1:
        return WalletV4R1(publicKey: publicKey.data)
      case .v4R2:
        return WalletV4R2(publicKey: publicKey.data)
      case .v5R1:
        return WalletV5R1(
          publicKey: publicKey.data,
          walletId: WalletId(
            networkGlobalId: Int32(
              isTestnet ? Network.testnet.rawValue : Network.mainnet.rawValue
            ),
            workchain: 0
          )
        )
      }
    }
  }
  
  var stateInit: StateInit {
    get throws {
      try contract.stateInit
    }
  }
  
  var address: Address {
    get throws {
      switch identity.kind {
      case .Regular:
        return try contract.address()
      case .Lockup:
        return try contract.address()
      case .Watchonly(let address):
        switch address {
        case .Resolved(let address):
          return address
        case .Domain(_, let address):
          return address
        }
      case .Signer, .SignerDevice:
        return try contract.address()
      case .Ledger:
        return try contract.address()
      }
    }
  }
  
  var friendlyAddress: FriendlyAddress {
    get throws {
      let isTestnet = isTestnet
      let address = try self.address
      return address.toFriendly(testOnly: isTestnet, bounceable: false)
    }
  }
  
  var addressToCopy: String? {
    try? friendlyAddress.toString()
  }
  
  var isTonconnectAvailable: Bool {
    switch kind {
    case .regular:
      return true
    case .lockup:
      return false
    case .watchonly:
      return false
    case .signer:
      return false
    case .ledger:
      return false
    }
  }
  
  var isBrowserAvailable: Bool {
    switch kind {
    case .regular:
      return true
    case .lockup:
      return false
    case .watchonly:
      return false
    case .signer:
      return false
    case .ledger:
      return false
    }
  }
  
  var isSendAvailable: Bool {
    switch kind {
    case .regular:
      return true
    case .lockup:
      return false
    case .watchonly:
      return false
    case .signer:
      return true
    case .ledger:
      return true
    }
  }
  
  var label: String {
    metaData.label
  }
  
  var emoji: String {
    switch metaData.icon {
    case .emoji(let string):
      return string
    case .icon(let string):
      return "👎🏽"
    }
  }
  
  var tintColor: WalletTintColor {
    metaData.tintColor
  }
  
  var emojiLabel: String {
    "\(emoji) \(label)"
  }
}


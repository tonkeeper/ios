import Foundation
import TonSwift

public enum WalletKind: Codable, Equatable, Identifiable {
  case Regular(TonSwift.PublicKey, WalletContractVersion)
  case Lockup(TonSwift.PublicKey, LockupConfig)
  case Watchonly(ResolvableAddress)
  case External(TonSwift.PublicKey, WalletContractVersion)
  
  public static func == (lhs: WalletKind, rhs: WalletKind) -> Bool {
    switch (lhs, rhs) {
    case (.Regular(let lpk, let lv), .Regular(let rpk, let rv)):
      return lpk == rpk && lv == rv
    case (.Lockup(let lpk, let lc), .Lockup(let rpk, let rc)):
      return lpk == rpk && lc == rc
    case (.Watchonly(let laddress), .Watchonly(let raddress)):
      return laddress == raddress
    case (.External(let lpk, let lv), .External(let rpk, let rv)):
      return lpk == rpk && lv == rv
    default: return false
    }
  }
  
  public var id: String {
    switch self {
    case .Regular(let publicKey, let walletContractVersion):
      return publicKey.hexString + walletContractVersion.rawValue
    case .Lockup(let publicKey, let lockupConfig):
      return publicKey.hexString
    case .Watchonly(let resolvableAddress):
      return String(resolvableAddress.hashValue)
    case .External(let publicKey, let walletContractVersion):
      return publicKey.hexString + walletContractVersion.rawValue
    }
  }
}

extension TonSwift.PublicKey: Equatable {
  public static func == (lhs: TonSwift.PublicKey, rhs: TonSwift.PublicKey) -> Bool {
    lhs.data == rhs.data
  }
}

extension WalletKind: CellCodable {
  public func storeTo(builder: Builder) throws {
    switch self {
    case let .Regular(publicKey, contractVersion):
      try builder.store(uint: 0, bits: 2)
      try publicKey.storeTo(builder: builder)
      try contractVersion.storeTo(builder: builder)
    case let .Lockup(publicKey, lockupConfig):
      try builder.store(uint: 1, bits: 2)
      try publicKey.storeTo(builder: builder)
      try lockupConfig.storeTo(builder: builder)
    case let .Watchonly(resolvableAddress):
      try builder.store(uint: 2, bits: 2)
      try resolvableAddress.storeTo(builder: builder)
    case let .External(publicKey, contractVersion):
      try builder.store(uint: 3, bits: 2)
      try publicKey.storeTo(builder: builder)
      try contractVersion.storeTo(builder: builder)
    }
  }
  
  public static func loadFrom(slice: Slice) throws -> WalletKind {
    return try slice.tryLoad { s in
      let type = try s.loadUint(bits: 2)
      switch type {
      case 0:
        let publicKey: TonSwift.PublicKey = try s.loadType()
        let contractVersion: WalletContractVersion = try s.loadType()
        return .Regular(publicKey, contractVersion)
      case 1:
        let publicKey: TonSwift.PublicKey = try s.loadType()
        let lockupConfig: LockupConfig = try s.loadType()
        return .Lockup(publicKey, lockupConfig)
      case 2:
        let resolvableAddress: ResolvableAddress = try s.loadType()
        return .Watchonly(resolvableAddress)
      case 3:
        let publicKey: TonSwift.PublicKey = try s.loadType()
        let contractVersion: WalletContractVersion = try s.loadType()
        return .External(publicKey, contractVersion)
      default:
        throw TonError.custom("Invalid WalletKind type");
      }
    }
  }
}

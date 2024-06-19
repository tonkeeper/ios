import Foundation
import TonSwift

public enum WalletKind: Codable, Equatable {
  case Regular(TonSwift.PublicKey, WalletContractVersion)
  case Lockup(TonSwift.PublicKey, LockupConfig)
  case Watchonly(ResolvableAddress)
  case Signer(TonSwift.PublicKey, WalletContractVersion)
  case SignerDevice(TonSwift.PublicKey, WalletContractVersion)
  case Ledger(TonSwift.PublicKey, WalletContractVersion, Wallet.LedgerDevice)
  
  public static func == (lhs: WalletKind, rhs: WalletKind) -> Bool {
    switch (lhs, rhs) {
    case (.Regular(let lpk, let lv), .Regular(let rpk, let rv)):
      return lpk == rpk && lv == rv
    case (.Lockup(let lpk, let lc), .Lockup(let rpk, let rc)):
      return lpk == rpk && lc == rc
    case (.Watchonly(let laddress), .Watchonly(let raddress)):
      return laddress == raddress
    case (.Signer(let lpk, let lv), .Signer(let rpk, let rv)):
      return lpk == rpk && lv == rv
    case (.SignerDevice(let lpk, let lv), .SignerDevice(let rpk, let rv)):
      return lpk == rpk && lv == rv
    case (.Ledger(let lpk, let lv, let lledger), .Ledger(let rpk, let rv, let rledger)):
      return lpk == rpk && lv == rv && lledger == rledger
    default: return false
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
      try builder.store(uint: 0, bits: 5)
      try publicKey.storeTo(builder: builder)
      try contractVersion.storeTo(builder: builder)
    case let .Lockup(publicKey, lockupConfig):
      try builder.store(uint: 1, bits: 5)
      try publicKey.storeTo(builder: builder)
      try lockupConfig.storeTo(builder: builder)
    case let .Watchonly(resolvableAddress):
      try builder.store(uint: 2, bits: 5)
      try resolvableAddress.storeTo(builder: builder)
    case let .Signer(publicKey, contractVersion):
      try builder.store(uint: 3, bits: 5)
      try publicKey.storeTo(builder: builder)
      try contractVersion.storeTo(builder: builder)
    case let .SignerDevice(publicKey, contractVersion):
      try builder.store(uint: 4, bits: 5)
      try publicKey.storeTo(builder: builder)
      try contractVersion.storeTo(builder: builder)
    case let .Ledger(publicKey, contractVersion, device):
      try builder.store(uint: 5, bits: 5)
      try publicKey.storeTo(builder: builder)
      try contractVersion.storeTo(builder: builder)
      try device.storeTo(builder: builder)
    }
  }
  
  public static func loadFrom(slice: Slice) throws -> WalletKind {
    return try slice.tryLoad { s in
      let type = try s.loadUint(bits: 5)
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
        return .Signer(publicKey, contractVersion)
      case 4:
        let publicKey: TonSwift.PublicKey = try s.loadType()
        let contractVersion: WalletContractVersion = try s.loadType()
        return .SignerDevice(publicKey, contractVersion)
      case 5:
        let publicKey: TonSwift.PublicKey = try s.loadType()
        let contractVersion: WalletContractVersion = try s.loadType()
        let device: Wallet.LedgerDevice = try s.loadType()
        return .Ledger(publicKey, contractVersion, device)
      default:
        throw TonError.custom("Invalid WalletKind type");
      }
    }
  }
}

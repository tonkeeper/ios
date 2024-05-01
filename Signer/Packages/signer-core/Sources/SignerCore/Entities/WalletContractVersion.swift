import TonSwift
import WalletCoreCore

extension WalletContractVersion: CellCodable {
  public func storeTo(builder: TonSwift.Builder) throws {
    switch self {
    case .NA:
      try builder.store(uint: 0, bits: 3)
    case .v3R1:
      try builder.store(uint: 1, bits: 3)
    case .v3R2:
      try builder.store(uint: 2, bits: 3)
    case .v4R1:
      try builder.store(uint: 3, bits: 3)
    case .v4R2:
      try builder.store(uint: 4, bits: 3)
    }
  }
  
  public static func loadFrom(slice: TonSwift.Slice) throws -> WalletCoreCore.WalletContractVersion {
    return try slice.tryLoad { slice in
      let revision = try slice.loadUint(bits: 3)
      switch revision {
      case 0:
        return .NA
      case 1:
        return .v3R1
      case 2:
        return .v3R2
      case 3:
        return .v4R1
      case 4:
        return .v4R2
      default:
        return .NA
      }
    }
  }
}

import Foundation
import TonSwift
import WalletCoreCore

struct WalletLink: Equatable {
  let network: WalletCoreCore.Network
  let publicKey: TonSwift.PublicKey
  let contractVersion: WalletCoreCore.WalletContractVersion
  
  static func == (lhs: WalletLink, rhs: WalletLink) -> Bool {
    lhs.network == rhs.network
    && lhs.publicKey.data == rhs.publicKey.data
    && lhs.contractVersion == rhs.contractVersion
  }
}

extension WalletLink: CellCodable {
  func storeTo(builder: TonSwift.Builder) throws {
    try network.storeTo(builder: builder)
    try publicKey.storeTo(builder: builder)
    try contractVersion.storeTo(builder: builder)
  }
  
  static func loadFrom(slice: TonSwift.Slice) throws -> WalletLink {
    return try slice.tryLoad { slice in
      let network: Network = try slice.loadType()
      let publicKey: TonSwift.PublicKey = try slice.loadType()
      let contractVetsion: WalletContractVersion = try slice.loadType()
      return WalletLink(
        network: network,
        publicKey: publicKey,
        contractVersion: contractVetsion)
    }
  }
}

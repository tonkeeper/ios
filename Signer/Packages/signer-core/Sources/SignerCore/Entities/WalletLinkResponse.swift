import Foundation
import TonSwift

struct WalletLinkResponse: Equatable {
  let walletLink: WalletLink
}

extension WalletLinkResponse: CellCodable {
  func storeTo(builder: Builder) throws {
    try walletLink.storeTo(builder: builder)
  }
  
  static func loadFrom(slice: Slice) throws -> WalletLinkResponse {
    return try slice.tryLoad { slice in
      let walletLink: WalletLink = try slice.loadType()
      return WalletLinkResponse(walletLink: walletLink)
    }
  }
}

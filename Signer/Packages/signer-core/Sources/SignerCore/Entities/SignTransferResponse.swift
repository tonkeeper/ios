import Foundation
import TonSwift

struct SignTransferResponse: Equatable {
  let walletLink: WalletLink
  let signedTransfer: Cell
}

extension SignTransferResponse: CellCodable {
  func storeTo(builder: Builder) throws {
    try walletLink.storeTo(builder: builder)
    try signedTransfer.storeTo(builder: builder)
  }
  
  static func loadFrom(slice: Slice) throws -> SignTransferResponse {
    return try slice.tryLoad { slice in
      let walletLink: WalletLink = try slice.loadType()
      let signedTransfer: Cell = try slice.loadType()
      return SignTransferResponse(
        walletLink: walletLink,
        signedTransfer: signedTransfer
      )
    }
  }
}

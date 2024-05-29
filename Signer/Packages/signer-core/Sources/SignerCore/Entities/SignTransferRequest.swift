import Foundation
import TonSwift

struct SignTransferRequest: Equatable {
  let walletLink: WalletLink
  let transfer: Cell
}

extension SignTransferRequest: CellCodable {
  func storeTo(builder: Builder) throws {
    try walletLink.storeTo(builder: builder)
    try transfer.storeTo(builder: builder)
  }
  
  static func loadFrom(slice: Slice) throws -> SignTransferRequest {
    return try slice.tryLoad { slice in
      let walletLink: WalletLink = try slice.loadType()
      let transfer: Cell = try slice.loadType()
      return SignTransferRequest(
        walletLink: walletLink,
        transfer: transfer
      )
    }
  }
}

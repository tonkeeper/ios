import Foundation
import TonSwift

enum OutputAction: Equatable {
  case linkWallet(WalletLinkResponse)
  case signTransfer(SignTransferResponse)
}

extension OutputAction: CellCodable {
  func storeTo(builder: Builder) throws {
    switch self {
    case .linkWallet(let response):
      try builder.store(uint: 0, bits: 3)
      try builder.store(response)
    case .signTransfer(let response):
      try builder.store(uint: 1, bits: 3)
      try builder.store(response)
    }
  }
  
  static func loadFrom(slice: Slice) throws -> OutputAction {
    return try slice.tryLoad { slice in
      let action = try slice.loadUint(bits: 3)
      switch action {
      case 0:
        let response: WalletLinkResponse = try slice.loadType()
        return .linkWallet(response)
      case 1:
        let response: SignTransferResponse = try slice.loadType()
        return .signTransfer(response)
      default:
        throw TonSwift.TonError.custom("Invalid OutputAction")
      }
    }
  }
}

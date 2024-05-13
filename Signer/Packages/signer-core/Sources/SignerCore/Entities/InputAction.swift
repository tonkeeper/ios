import Foundation
import TonSwift

enum InputAction: Equatable {
  case linkWallet
  case signTransfer(SignTransferRequest)
}

extension InputAction: CellCodable {
  func storeTo(builder: Builder) throws {
    switch self {
    case .linkWallet:
      try builder.store(uint: 0, bits: 3)
    case .signTransfer(let request):
      try builder.store(uint: 1, bits: 3)
      try builder.store(request)
    }
  }
  
  static func loadFrom(slice: Slice) throws -> InputAction {
    return try slice.tryLoad { slice in
      let action = try slice.loadUint(bits: 3)
      switch action {
      case 0:
        return .linkWallet
      case 1:
        let request: SignTransferRequest = try slice.loadType()
        return .signTransfer(request)
      default:
        throw TonSwift.TonError.custom("Invalid InputAction")
      }
    }
  }
}

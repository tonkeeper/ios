import Foundation
import TonSwift
import TonAPI

extension JettonTransferPayload {
  init(customPayload: String?, stateInit: String?) throws {
    if let customPayload = customPayload {
      self.customPayload = try Cell.fromBoc(src: Data(hex: customPayload))[0]
    } else {
      self.customPayload = nil
    }
    
    if let stateInit = stateInit {
      self.stateInit = try Cell.fromBoc(src: Data(hex: stateInit))[0]
    } else {
      self.stateInit = nil
    }
  }
}

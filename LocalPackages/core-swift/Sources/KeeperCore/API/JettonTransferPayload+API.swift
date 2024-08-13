import Foundation
import TonSwift
import TonAPI

extension JettonTransferPayload {
  init(custom_payload: String?, state_init: String?) throws {
    if let customPayload = custom_payload {
      self.custom_payload = try Cell.fromBoc(src: Data(hex: customPayload))[0]
    } else {
      self.custom_payload = nil
    }
    
    if let stateInit = state_init {
      self.state_init = try Cell.fromBoc(src: Data(hex: stateInit))[0]
    } else {
      self.state_init = nil
    }
  }
}

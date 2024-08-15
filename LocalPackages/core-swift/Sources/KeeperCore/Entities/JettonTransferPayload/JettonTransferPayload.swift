import Foundation
import TonSwift

public struct JettonTransferPayload {
  public let customPayload: Cell?
  public let stateInit: Cell?
  
  public init(customPayload: Cell?, stateInit: Cell?) {
    self.customPayload = customPayload
    self.stateInit = stateInit
  }
}

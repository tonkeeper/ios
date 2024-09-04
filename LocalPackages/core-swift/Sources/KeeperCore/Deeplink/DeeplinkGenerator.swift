import Foundation
import TonSwift

public struct DeeplinkGenerator {
  public func generateTransferDeeplink(with addressString: String, jettonAddress: Address?) throws -> TonDeeplink {
    TonDeeplink.transfer(recipient: addressString, jettonAddress: jettonAddress)
  }
  
  public func generateTonSignOpenDeeplink() -> TonsignDeeplink {
    .plain
  }
  
  public init() {}
}

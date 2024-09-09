import Foundation
import TonSwift
import BigInt

public struct DeeplinkGenerator {
  public func generateTransferDeeplink(with addressString: String, amount: BigUInt? = nil, comment: String? = nil, jettonAddress: Address?) throws -> TonDeeplink {
    TonDeeplink.transfer(recipient: addressString, amount: amount, comment: comment, jettonAddress: jettonAddress)
  }
  
  public func generateTonSignOpenDeeplink() -> TonsignDeeplink {
    .plain
  }
  
  public init() {}
}

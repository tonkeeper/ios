import Foundation
import TonSwift

public struct DeeplinkGenerator {
  public func generateTransferDeeplink(with addressString: String, jettonAddress: Address?) throws -> TonDeeplink {
    return TonDeeplink.transfer(recipient: addressString, jettonAddress: jettonAddress)
  }
}

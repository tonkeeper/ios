import Foundation
import TonSwift

public struct Domain: Equatable {
  public let domain: String
  public let friendlyAddress: FriendlyAddress
}

extension FriendlyAddress {
  public static func == (lhs: FriendlyAddress, rhs: FriendlyAddress) -> Bool {
    // TODO: move it to TonSwift?
    lhs.address == rhs.address && lhs.isBounceable == rhs.isBounceable && lhs.isTestOnly == rhs.isTestOnly
  }
}

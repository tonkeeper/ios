import Foundation
import TonSwift

public struct Domain: Equatable {
  public let domain: String
  public let friendlyAddress: FriendlyAddress
}

extension FriendlyAddress: Equatable {
  public static func == (lhs: FriendlyAddress, rhs: FriendlyAddress) -> Bool {
    lhs.address == rhs.address && lhs.isBounceable == rhs.isBounceable && lhs.isTestOnly == rhs.isTestOnly
  }
}

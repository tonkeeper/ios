import Foundation
import BigInt

public extension StakingPool.Implementation {
  var withdrawalFee: BigUInt  {
    switch self.type {
    case .liquidTF:
      return BigUInt(integerLiteral: 1_000_000_000)
    case .tf:
      return BigUInt(integerLiteral: 1_000_000_000)
    case .whales:
      return BigUInt(integerLiteral: 200_000_000)
    }
  }
}

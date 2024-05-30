import TonSwift
import BigInt

public struct AccountStakingInfo: Codable {
  public let address: Address
  public let amount: BigUInt
  public let pendingDeposit: BigUInt
  public let pendingWithdraw: BigUInt
  public let readyToWithdraw: BigUInt
}

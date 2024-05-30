import BigInt

public struct AccountStakingInfo: Codable {
    public let pool: String
    public let amount: BigUInt
    public let pendingDeposit: BigUInt
    public let pendingWithdraw: BigUInt
    public let readyWithdraw: BigUInt
}

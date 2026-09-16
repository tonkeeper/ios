@preconcurrency import BigInt

public struct MultichainTransactionEmulationResult: Sendable, Hashable {
    public let fee: BigUInt
    public let asset: MultichainAssetDetails
    public let adjustedAmount: BigUInt?
    public let isMaxAmount: Bool
    public let isInsufficientBalance: Bool

    public init(
        fee: BigUInt,
        asset: MultichainAssetDetails,
        adjustedAmount: BigUInt? = nil,
        isMaxAmount: Bool = false,
        isInsufficientBalance: Bool = false
    ) {
        self.fee = fee
        self.asset = asset
        self.adjustedAmount = adjustedAmount
        self.isMaxAmount = isMaxAmount
        self.isInsufficientBalance = isInsufficientBalance
    }
}

import Foundation

public struct SwapConfirmationData: Encodable {
    public let fromAsset: String
    public let toAsset: String
    public let fromAmount: String
    public let toAmount: String
    public let userAddress: String
    public let isSend: Bool

    public init(
        fromAsset: String,
        toAsset: String,
        fromAmount: String,
        toAmount: String,
        userAddress: String,
        isSend: Bool
    ) {
        self.fromAsset = fromAsset
        self.toAsset = toAsset
        self.fromAmount = fromAmount
        self.toAmount = toAmount
        self.userAddress = userAddress
        self.isSend = isSend
    }
}

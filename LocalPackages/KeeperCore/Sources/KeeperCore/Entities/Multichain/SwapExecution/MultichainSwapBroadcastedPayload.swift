public struct MultichainSwapBroadcastedPayload: Sendable, Hashable {
    public let payloadId: String
    public let kind: String
    public let payloadType: String
    public let txHash: String

    public init(
        payloadId: String,
        kind: String,
        payloadType: String,
        txHash: String
    ) {
        self.payloadId = payloadId
        self.kind = kind
        self.payloadType = payloadType
        self.txHash = txHash
    }
}

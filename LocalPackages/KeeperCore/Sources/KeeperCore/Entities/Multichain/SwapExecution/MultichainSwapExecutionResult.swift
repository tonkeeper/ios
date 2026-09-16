public struct MultichainSwapExecutionResult: Sendable, Hashable {
    public var routeId: String
    public var txHash: String
    public var broadcastedPayloads: [MultichainSwapBroadcastedPayload]

    public init(
        routeId: String,
        txHash: String,
        broadcastedPayloads: [MultichainSwapBroadcastedPayload]
    ) {
        self.routeId = routeId
        self.txHash = txHash
        self.broadcastedPayloads = broadcastedPayloads
    }
}

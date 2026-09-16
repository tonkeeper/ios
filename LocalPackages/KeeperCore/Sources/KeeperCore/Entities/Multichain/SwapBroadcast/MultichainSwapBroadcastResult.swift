struct MultichainSwapBroadcastResult: Hashable {
    let txHash: String
    let broadcastedPayloads: [MultichainSwapBroadcastedPayload]
}

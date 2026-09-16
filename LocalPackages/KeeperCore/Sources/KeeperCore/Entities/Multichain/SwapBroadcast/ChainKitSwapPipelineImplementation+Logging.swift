extension ChainKitSwapPipelineImplementation {
    func swapPayloadLogInfo(
        payload: MultichainSwapPreparedPayload,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        additional: [String: String] = [:]
    ) -> [String: String] {
        var info = [
            "payloadId": payload.payloadId,
            "kind": payload.kind,
            "payloadType": payload.payloadType,
            "calldataType": payload.calldataPayloadType?.rawValue ?? "unset",
            "chainId": payload.chainId,
            "sourceAsset": sourceAsset.asset.assetId,
            "destinationAsset": destinationAsset.asset.assetId,
        ]
        additional.forEach { info[$0.key] = $0.value }
        return info
    }

    func swapPayloadsLogInfo(
        payloads: [MultichainSwapPreparedPayload],
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        additional: [String: String] = [:]
    ) -> [String: String] {
        var info = [
            "payloads": payloads.map(\.description).joined(separator: ","),
            "sourceAsset": sourceAsset.asset.assetId,
            "destinationAsset": destinationAsset.asset.assetId,
        ]
        additional.forEach { info[$0.key] = $0.value }
        return info
    }
}

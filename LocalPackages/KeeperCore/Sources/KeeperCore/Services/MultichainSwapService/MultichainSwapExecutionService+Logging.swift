import TKLogging

extension MultichainSwapExecutionServiceImplementation {
    static func routeLogInfo(
        route: MultichainSwapRoute,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        additional: [String: String] = [:]
    ) -> [String: String] {
        var info = [
            "routeId": route.routeId,
            "sourceAsset": sourceAsset.asset.assetId,
            "destinationAsset": destinationAsset.asset.assetId,
            "aggregator": route.aggregator,
            "protocol": route.protocolSlug ?? "",
            "riskLevel": route.riskLevel,
        ]
        additional.forEach { info[$0.key] = $0.value }
        return info
    }

    static func executionPlanLogInfo(
        executionPlan: MultichainSwapExecutionPlan,
        sourceAsset: MultichainAsset,
        destinationAsset: MultichainAsset,
        additional: [String: String] = [:]
    ) -> [String: String] {
        var info = [
            "routeId": executionPlan.routeId,
            "sourceAsset": sourceAsset.asset.assetId,
            "destinationAsset": destinationAsset.asset.assetId,
        ]
        additional.forEach { info[$0.key] = $0.value }
        return info
    }

    static func payloadLogInfo(
        _ payload: MultichainSwapPreparedPayload,
        routeId: String,
        additional: [String: String] = [:]
    ) -> [String: String] {
        var info = [
            "routeId": routeId,
            "payloadId": payload.payloadId,
            "kind": payload.kind,
            "payloadType": payload.payloadType,
            "calldataType": payload.calldataPayloadType?.rawValue ?? "unset",
            "chainId": payload.chainId,
            "chainFamily": payload.chainFamily,
        ]
        additional.forEach { info[$0.key] = $0.value }
        return info
    }

    static func payloadOrder(_ payloads: [MultichainSwapPreparedPayload]) -> String {
        payloads.map(\.description).joined(separator: ",")
    }

    static func feeAssetIds(_ fees: [MultichainTransactionEmulationResult]) -> String {
        fees.map(\.asset.assetId).joined(separator: ",")
    }

    static func feeMethodIds(_ options: [MultichainSwapFeeOption]) -> String {
        options.map(\.logValue).joined(separator: ",")
    }
}

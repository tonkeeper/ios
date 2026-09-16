import KeeperCore

struct MultichainSwapConfirmationLogInfoMaker {
    let priceImpactResolver: MultichainSwapConfirmationPriceImpactResolver

    func make(
        input: MultichainSwapConfirmationInput,
        additional: [String: String] = [:]
    ) -> [String: String] {
        let userInput = input.userInput
        let route = input.quoteState.route
        var info = [
            "routeId": route.routeId,
            "sourceAsset": userInput.sendAsset.asset.assetId,
            "destinationAsset": userInput.receiveAsset.asset.assetId,
            "aggregator": route.aggregator,
            "protocol": route.protocolSlug ?? "",
            "riskLevel": route.riskLevel,
        ]
        if let valueDifferenceBps = route.valueDifferenceBps {
            info["valueDifferenceBps"] = "\(valueDifferenceBps)"
        }
        if let priceImpactBps = priceImpactResolver.priceImpactBps(input: input) {
            info["priceImpactBps"] = "\(priceImpactBps)"
            info["priceImpactSeverity"] = MultichainSwapPriceImpactSeverity(
                bps: priceImpactBps
            ).rawValue
        }
        additional.forEach { info[$0.key] = $0.value }
        return info
    }
}

import KeeperCore

extension MultichainAssetDetails {
    init(assetInfo: TradingAssetInfo, swapAggregators: Set<MultichainSwapAggregator>? = nil) {
        self.init(
            assetId: assetInfo.assetId,
            name: assetInfo.title,
            symbol: assetInfo.symbol,
            decimals: assetInfo.decimals,
            image: assetInfo.imageURL?.absoluteString ?? "",
            swapAggregators: swapAggregators
        )
    }
}

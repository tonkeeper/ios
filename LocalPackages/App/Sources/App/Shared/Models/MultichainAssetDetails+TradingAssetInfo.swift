import KeeperCore

extension MultichainAssetDetails {
    init(assetInfo: TradingAssetInfo) {
        self.init(
            assetId: assetInfo.assetId,
            name: assetInfo.title,
            symbol: assetInfo.symbol,
            decimals: assetInfo.decimals,
            image: assetInfo.imageURL?.absoluteString ?? ""
        )
    }
}

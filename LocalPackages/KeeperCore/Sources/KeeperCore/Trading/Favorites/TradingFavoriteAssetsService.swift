import Foundation

public protocol TradingFavoriteAssetsService {
    var assets: [TradingFavoriteAsset] { get async }
    func cachedMarketItems(assetIDs: [String]) async -> [String: TradingMarketItem]

    func isFavorite(id: String) async -> Bool
    func setFavorite(_ isFavorite: Bool, context: TradingFavoriteAssetContext) async
    func updateAsset(_ context: TradingFavoriteAssetContext) async
    func marketItems(assetIDs: [String], forceRefresh: Bool) async -> [String: TradingMarketItem]
}

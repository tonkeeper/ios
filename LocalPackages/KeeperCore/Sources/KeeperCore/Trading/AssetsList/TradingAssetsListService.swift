public enum TradingAssetsListServiceFailure: Error {
    case networkError
    case apiError(
        message: String?
    )
}

public protocol TradingAssetsListService {
    func load(
        query: String?,
        category: TradingAssetCategory
    ) async throws(TradingAssetsListServiceFailure) -> TradingAssetListSnapshot

    func loadNextPage(
        query: String?,
        category: TradingAssetCategory
    ) async throws(TradingAssetsListServiceFailure) -> TradingAssetListSnapshot?
}

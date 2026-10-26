@frozen public enum TradingAssetDetailsServiceFailure: Error {
    case networkError
    case notFound
    case apiError(
        message: String?
    )
}

public protocol TradingAssetDetailsService {
    func assetDetails(
        for assetId: String
    ) async -> TradingAssetDetails?

    func loadAssetDetails(
        id: String
    ) async throws(TradingAssetDetailsServiceFailure) -> TradingAssetDetails
}

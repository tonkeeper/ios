public protocol MultichainSwapService {
    func listCrossSwapAssets(query: MultichainSwapAssetsQuery) async throws -> [MultichainSwapAsset]
    func getCrossSwapAsset(assetId: String) async throws -> MultichainSwapAsset
    func getCrossSwapConfig(
        walletId: String,
        fromAssetId: String?,
        toAssetId: String?
    ) async throws -> MultichainSwapConfig
    func createCrossSwapQuote(
        request: MultichainSwapQuoteRequest,
        walletId: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote
    func prepareCrossSwapRoute(
        routeId: String,
        request: MultichainSwapPrepareRouteRequest?,
        walletId: String?
    ) async throws -> MultichainSwapPrepare
}

final class MultichainSwapServiceImplementation: MultichainSwapService {
    private let multichainSwapAPI: MultichainSwapAPI

    init(multichainSwapAPI: MultichainSwapAPI) {
        self.multichainSwapAPI = multichainSwapAPI
    }

    func listCrossSwapAssets(query: MultichainSwapAssetsQuery) async throws -> [MultichainSwapAsset] {
        try await multichainSwapAPI.listCrossSwapAssets(query: query)
    }

    func getCrossSwapAsset(assetId: String) async throws -> MultichainSwapAsset {
        try await multichainSwapAPI.getCrossSwapAsset(assetId: assetId)
    }

    func getCrossSwapConfig(
        walletId: String,
        fromAssetId: String?,
        toAssetId: String?
    ) async throws -> MultichainSwapConfig {
        try await multichainSwapAPI.getCrossSwapConfig(
            walletId: walletId,
            fromAssetId: fromAssetId,
            toAssetId: toAssetId
        )
    }

    func createCrossSwapQuote(
        request: MultichainSwapQuoteRequest,
        walletId: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        try await multichainSwapAPI.createCrossSwapQuote(request: request, walletId: walletId)
    }

    func prepareCrossSwapRoute(
        routeId: String,
        request: MultichainSwapPrepareRouteRequest?,
        walletId: String?
    ) async throws -> MultichainSwapPrepare {
        try await multichainSwapAPI.prepareCrossSwapRoute(
            routeId: routeId,
            request: request,
            walletId: walletId
        )
    }
}

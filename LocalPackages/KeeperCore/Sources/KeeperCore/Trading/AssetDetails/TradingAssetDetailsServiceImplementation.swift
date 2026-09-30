import TKLogging
import TKTradingAPI

actor TradingAssetDetailsServiceImplementation {
    private let api: TradingAPI
    private let cache: InMemoryKeyedCache<String, TradingAssetDetails>
    private let requestContextProvider: TradingRequestContextProvider

    init(
        api: TradingAPI,
        cache: InMemoryKeyedCache<String, TradingAssetDetails>,
        requestContextProvider: TradingRequestContextProvider
    ) {
        self.api = api
        self.cache = cache
        self.requestContextProvider = requestContextProvider
    }
}

extension TradingAssetDetailsServiceImplementation: TradingAssetDetailsService {
    func assetDetails(
        for assetId: String
    ) async -> TradingAssetDetails? {
        await cache.get(assetId)
    }

    func loadAssetDetails(
        id: String
    ) async throws(TradingAssetDetailsServiceFailure) -> TradingAssetDetails {
        Log.trade.i("load details for asset \(id)")
        let requestContext = await requestContextProvider.makeRequestContext()
        let response: Components.Schemas.AssetDetailsResponse
        do {
            response = try await api.getAssetsDetailsV2(
                requestContext: requestContext,
                assetId: id
            )
        } catch {
            Log.trade.i("load details failed \(error.localizedDescription)")
            switch error {
            case .transportError:
                throw .networkError
            default:
                throw .apiError(message: error.localizedDescription)
            }
        }
        let details = TradingAssetDetails(
            response: response,
            currency: requestContext.currency
        )
        await cache.set(details, for: id)
        Log.trade.i("load details for asset \(id) - success")
        return details
    }
}

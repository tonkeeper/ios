import TKLogging
import TKTradingAPI

actor TradingShelvesServiceImplementation {
    private let api: TradingAPI
    private let cache: InMemoryKeyedCache<TradingShelvesMode, TradingShelvesSnapshot>
    private let marketItemsCache: InMemoryKeyedCache<String, TradingMarketItem>
    private let requestContextProvider: TradingRequestContextProvider

    init(
        api: TradingAPI,
        cache: InMemoryKeyedCache<TradingShelvesMode, TradingShelvesSnapshot>,
        marketItemsCache: InMemoryKeyedCache<String, TradingMarketItem>,
        requestContextProvider: TradingRequestContextProvider
    ) {
        self.api = api
        self.cache = cache
        self.marketItemsCache = marketItemsCache
        self.requestContextProvider = requestContextProvider
    }
}

extension TradingShelvesServiceImplementation: TradingShelvesService {
    func shelves(for mode: TradingShelvesMode) async -> TradingShelvesSnapshot? {
        await cache.get(mode)
    }

    func loadShelves(for mode: TradingShelvesMode) async throws(LoadShelvesFailure) -> TradingShelvesSnapshot {
        Log.trade.i("load shelves for \(mode)")
        let snapshot: TradingShelvesSnapshot
        do {
            let requestContext = await requestContextProvider.makeRequestContext()
            switch mode {
            case .multichain:
                let response = try await api.getShelvesV2(requestContext: requestContext)
                snapshot = TradingShelvesSnapshot(
                    response: response,
                    currency: requestContext.currency
                )
            case .legacy:
                let response = try await api.getShelves(requestContext: requestContext)
                snapshot = TradingShelvesSnapshot(
                    response: response,
                    currency: requestContext.currency
                )
            }
        } catch {
            Log.trade.i("load shelves failed \(error.localizedDescription)")
            switch error {
            case .transportError:
                throw .networkError
            default:
                throw .apiError(message: error.localizedDescription)
            }
        }
        await cache.set(snapshot, for: mode)
        let items = snapshot.shelves
            .flatMap(\.groups)
            .flatMap(\.grids)
            .flatMap(\.items)
            .reduce(into: [String: TradingMarketItem]()) { $0[$1.id] = $1 }
        await marketItemsCache.merge(items)
        Log.trade.i("load shelves for \(mode) - success")
        return snapshot
    }
}

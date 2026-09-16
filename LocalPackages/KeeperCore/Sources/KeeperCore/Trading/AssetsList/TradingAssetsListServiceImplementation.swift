import Foundation
import TKLogging
import TKTradingAPI

actor TradingAssetsListServiceImplementation {
    private let api: TradingAPI
    private let cache: InMemoryKeyedCache<QueryDescriptor, TradingAssetListSnapshot>
    private let requestContextProvider: TradingRequestContextProvider

    init(
        api: TradingAPI,
        cache: InMemoryKeyedCache<QueryDescriptor, TradingAssetListSnapshot>,
        requestContextProvider: TradingRequestContextProvider
    ) {
        self.api = api
        self.cache = cache
        self.requestContextProvider = requestContextProvider
    }
}

extension TradingAssetsListServiceImplementation: TradingAssetsListService {
    func get(
        query: String?,
        category: TradingAssetCategory
    ) async -> TradingAssetListSnapshot? {
        let descriptor = descriptor(query: query, category: category)
        return await cache.get(descriptor)
    }

    func load(
        query: String?,
        category: TradingAssetCategory
    ) async throws(TradingAssetsListServiceFailure) -> TradingAssetListSnapshot {
        let descriptor = descriptor(query: query, category: category)
        Log.trade.i("load assets list for category \(descriptor.category.rawValue), query \(descriptor.query ?? "nil")")
        let snapshot = try await loadPage(descriptor: descriptor, cursor: nil)
        await cache.set(snapshot, for: descriptor)
        Log.trade.i("load assets list for category \(descriptor.category.rawValue), query \(descriptor.query ?? "nil") - success, new cursor: \(snapshot.nextCursor?.pretty.masked ?? "nil")")
        return snapshot
    }

    func loadNextPage(
        query: String?,
        category: TradingAssetCategory
    ) async throws(TradingAssetsListServiceFailure) -> TradingAssetListSnapshot? {
        let descriptor = descriptor(query: query, category: category)
        guard let cachedSnapshot = await cache.get(descriptor),
              let nextCursor = cachedSnapshot.nextCursor
        else {
            return nil
        }
        Log.trade.i(
            "load next assets list page for category \(descriptor.category.rawValue), query \(descriptor.query ?? "nil"), cursor \(nextCursor.pretty.masked)"
        )
        let nextPage = try await loadPage(
            descriptor: descriptor,
            cursor: nextCursor
        )
        let mergedSnapshot = cachedSnapshot.merged(with: nextPage)
        await cache.set(mergedSnapshot, for: descriptor)
        Log.trade.i(
            "load next assets list page for category \(descriptor.category.rawValue), query \(descriptor.query ?? "nil"), cursor \(nextCursor.pretty.masked) - success. new cursor: \(mergedSnapshot.nextCursor?.pretty.masked ?? "nil")"
        )
        return mergedSnapshot
    }
}

extension TradingAssetsListServiceImplementation {
    private static var pageSize: Int {
        30
    }

    struct QueryDescriptor: Hashable {
        var query: String?
        var category: TradingAssetCategory
    }

    private func descriptor(
        query: String?,
        category: TradingAssetCategory
    ) -> QueryDescriptor {
        let normalizedQuery: String?
        if let query {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            normalizedQuery = trimmed.isEmpty ? nil : trimmed
        } else {
            normalizedQuery = nil
        }
        return QueryDescriptor(
            query: normalizedQuery,
            category: category
        )
    }

    private func loadPage(
        descriptor: QueryDescriptor,
        cursor: String?
    ) async throws(TradingAssetsListServiceFailure) -> TradingAssetListSnapshot {
        let requestContext = await requestContextProvider.makeRequestContext()
        let response: Components.Schemas.AssetsCatalogResponse
        do {
            response = try await api.getAssetsCatalog(
                requestContext: requestContext,
                tab: descriptor.category.tradingApiValue,
                query: descriptor.query,
                cursor: cursor,
                pageSize: Self.pageSize,
                sourceShelf: nil
            )
        } catch {
            Log.trade.i(
                "load assets list failed for category \(descriptor.category.rawValue), query \(descriptor.query ?? "nil"), cursor \(cursor ?? "nil"): \(error.localizedDescription)"
            )
            switch error {
            case .transportError:
                throw .networkError
            default:
                throw .apiError(message: error.localizedDescription)
            }
        }

        return TradingAssetListSnapshot(
            generatedAt: Date().addingTimeInterval(-TimeInterval(response.data_freshness_sec)),
            currency: requestContext.currency,
            assets: response.items.map(TradingAsset.init),
            nextCursor: response.next_cursor
        )
    }
}

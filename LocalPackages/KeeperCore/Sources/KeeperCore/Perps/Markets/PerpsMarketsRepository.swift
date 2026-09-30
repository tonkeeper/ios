import Foundation
import TKLogging
import TKTradingAPI

enum PerpsMarketsRepositoryError: Error {
    case marketNotFound
    case unsupportedAsset
}

public actor PerpsMarketsRepository {
    static let pageSize = 50
    public static let minimumPageSize = 10
    static let detailsLifetime: TimeInterval = 120

    private let api: TradingAPI
    private let requestContextProvider: TradingRequestContextProvider
    private var detailsById: [Int64: PerpsMarketDetails] = [:]
    private var detailsFetchedAt: [Int64: Date] = [:]
    private var symbolsById: [Int64: String] = [:]
    private var detailsRequests: [Int64: Task<PerpsMarketDetails, Error>] = [:]

    init(api: TradingAPI, requestContextProvider: TradingRequestContextProvider) {
        self.api = api
        self.requestContextProvider = requestContextProvider
    }

    public func markets(query: String?, sort: PerpsMarketsSort, cursor: String?) async throws -> PerpsMarketsPage {
        try await markets(query: query, sort: sort, cursor: cursor, pageSize: Self.pageSize)
    }

    public func markets(query: String?, sort: PerpsMarketsSort, cursor: String?, pageSize: Int) async throws -> PerpsMarketsPage {
        let requestContext = await requestContextProvider.makeRequestContext()
        let response = try await api.getAssetsCatalogV2(
            requestContext: requestContext.withCurrency(.USD),
            tab: .perpetuals,
            query: query?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            sort: sort.tradingApiValue,
            order: .desc,
            cursor: cursor,
            pageSize: pageSize,
            sourceShelf: nil
        )
        let items = response.items.compactMap(PerpsMarketSummary.init(item:))
        let skipped = response.items.count - items.count
        if skipped > 0 {
            Log.w("🪵 Perps: skipped \(skipped) catalog rows without a perp market id")
        }
        for item in items {
            symbolsById[item.marketId] = item.symbol
        }
        return PerpsMarketsPage(items: items, nextCursor: response.next_cursor?.nilIfEmpty)
    }

    public func catalogSearch(
        query: String?,
        chain: String?,
        showPerps: Bool,
        sort: MultichainAssetSearchSort,
        cursor: String?,
        pageSize: Int
    ) async throws -> TradingCatalogPage {
        let requestContext = await requestContextProvider.makeRequestContext()
        let tradingSort = sort.tradingCatalogSort
        let response = try await api.getAssetsCatalogV2(
            requestContext: requestContext,
            tab: .all,
            query: query?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            sort: tradingSort.0,
            order: tradingSort.1,
            cursor: cursor,
            pageSize: pageSize,
            sourceShelf: nil,
            showPerps: (showPerps && chain == nil) ? true : nil,
            chain: chain,
            filter: nil
        )
        return TradingCatalogPage(
            rows: response.items.compactMap(TradingCatalogRow.init(item:)),
            nextCursor: response.next_cursor?.nilIfEmpty
        )
    }

    func marketDetails(marketId: Int64) async throws -> PerpsMarketDetails {
        let cached = detailsById[marketId]
        if let cached,
           let fetchedAt = detailsFetchedAt[marketId],
           Date().timeIntervalSince(fetchedAt) < Self.detailsLifetime
        {
            return cached
        }
        do {
            return try await fetchDetails(marketId: marketId)
        } catch PerpsMarketsRepositoryError.marketNotFound {
            throw PerpsMarketsRepositoryError.marketNotFound
        } catch {
            guard let cached else { throw error }
            return cached
        }
    }

    func reloadMarketDetails(marketId: Int64) async throws -> PerpsMarketDetails {
        try await fetchDetails(marketId: marketId)
    }

    func market(marketId: Int64) async -> PerpsMarketMetadata? {
        do {
            return try await marketDetails(marketId: marketId).metadata
        } catch {
            Log.w("🪵 Perps: market \(marketId) details lookup failed — \(error)")
            return nil
        }
    }

    func tickers(for marketIds: Set<Int64>) async throws -> [Int64: String] {
        var tickers: [Int64: String] = [:]
        for marketId in marketIds.sorted() {
            if let symbol = symbolsById[marketId] {
                tickers[marketId] = PerpsMarketTicker.make(base: symbol, quote: nil)
            } else {
                tickers[marketId] = try await marketDetails(marketId: marketId).metadata.ticker
            }
        }
        return tickers
    }

    private func fetchDetails(marketId: Int64) async throws -> PerpsMarketDetails {
        if let request = detailsRequests[marketId] {
            return try await request.value
        }
        let request = Task {
            let requestContext = await requestContextProvider.makeRequestContext()
            let response: Components.Schemas.AssetDetailsResponse
            do {
                response = try await api.getAssetsDetailsV2(
                    requestContext: requestContext,
                    assetId: PerpsMarketAssetID.make(marketId: marketId)
                )
            } catch TradingAPIError.notFound {
                throw PerpsMarketsRepositoryError.marketNotFound
            }
            guard let details = PerpsMarketDetails(response: response) else {
                throw PerpsMarketsRepositoryError.unsupportedAsset
            }
            return details
        }
        detailsRequests[marketId] = request
        defer { detailsRequests[marketId] = nil }
        let details = try await request.value
        detailsById[marketId] = details
        detailsFetchedAt[marketId] = Date()
        symbolsById[marketId] = details.metadata.symbol
        return details
    }
}

extension PerpsMarketsRepository: PerpsMarketsReading, PerpsMarketsSearching, TradingCatalogSearching {}

struct PerpsMarketMetadata: Equatable, Sendable {
    let marketId: Int64
    let symbol: String
    let ticker: String
    let status: String
    let markPrice: Double?
    let lastTradePrice: Double?
    let priceChangePercent: Double
    let volume24h: Double
    let openInterest: Double
    let maxLeverage: Double
    let fundingRatePercent: Double?
    let priceDecimals: Int
    let sizeDecimals: Int
    let minBaseSize: Double

    var displayPrice: Double {
        markPrice ?? lastTradePrice ?? 0
    }
}

protocol PerpsMarketsReading: AnyObject {
    func markets(query: String?, sort: PerpsMarketsSort, cursor: String?) async throws -> PerpsMarketsPage
    func marketDetails(marketId: Int64) async throws -> PerpsMarketDetails
    func reloadMarketDetails(marketId: Int64) async throws -> PerpsMarketDetails
    func market(marketId: Int64) async -> PerpsMarketMetadata?
    func tickers(for marketIds: Set<Int64>) async throws -> [Int64: String]
}

extension PerpsMarketsReading {
    func reloadMarketDetails(marketId: Int64) async throws -> PerpsMarketDetails {
        try await marketDetails(marketId: marketId)
    }

    func market(marketId: Int64) async -> PerpsMarketMetadata? {
        (try? await marketDetails(marketId: marketId))?.metadata
    }

    func tickers(for marketIds: Set<Int64>) async throws -> [Int64: String] {
        var tickers: [Int64: String] = [:]
        for marketId in marketIds.sorted() {
            tickers[marketId] = try await marketDetails(marketId: marketId).metadata.ticker
        }
        return tickers
    }
}

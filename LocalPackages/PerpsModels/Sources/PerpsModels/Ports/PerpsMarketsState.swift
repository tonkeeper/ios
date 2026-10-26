import Foundation

public struct PerpsMarkets: Equatable, Sendable {
    public let sort: PerpsMarketsSort
    public let items: [PerpsMarketSummary]
    public let livePrices: [Int64: Double]
    public let hasNextPage: Bool
    public let isLoadingNextPage: Bool

    public init(
        sort: PerpsMarketsSort,
        items: [PerpsMarketSummary],
        livePrices: [Int64: Double],
        hasNextPage: Bool,
        isLoadingNextPage: Bool
    ) {
        self.sort = sort
        self.items = items
        self.livePrices = livePrices
        self.hasNextPage = hasNextPage
        self.isLoadingNextPage = isLoadingNextPage
    }

    public func livePrice(marketId: Int64) -> Double? {
        livePrices[marketId]
    }

    public func price(marketId: Int64) -> Double? {
        if let livePrice = livePrices[marketId] {
            return livePrice
        }
        guard let item = items.first(where: { $0.marketId == marketId }), item.hasPrice else { return nil }
        return item.price
    }
}

public enum PerpsMarketsState {
    case idle
    case loading
    case loaded(PerpsMarkets)
    case failed

    public func livePrice(marketId: Int64) -> Double? {
        guard case let .loaded(markets) = self else { return nil }
        return markets.livePrice(marketId: marketId)
    }

    public func price(marketId: Int64) -> Double? {
        guard case let .loaded(markets) = self else { return nil }
        return markets.price(marketId: marketId)
    }
}

public extension PerpsMarketsState {
    typealias Markets = PerpsMarkets
}

public enum PerpsMarketDetailsState: Equatable {
    case idle
    case loading
    case loaded(PerpsAssetMarketSnapshot)
    case failed
    case notFound
}

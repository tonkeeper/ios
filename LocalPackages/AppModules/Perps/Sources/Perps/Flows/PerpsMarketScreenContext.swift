import PerpsModels

struct PerpsMarketScreenContext {
    let market: PerpsAssetMarketSnapshot
    let markPrice: Double?
    let position: PerpsPositionSummary?

    init(market: PerpsAssetMarketSnapshot, markPrice: Double?, lifecycle: PerpsMarketLifecycle) {
        self.market = market
        self.markPrice = markPrice
        position = if case let .open(summary) = lifecycle { summary } else { nil }
    }

    var marketId: Int64 {
        market.marketId
    }

    func with(_ lifecycle: PerpsMarketLifecycle) -> PerpsMarketScreenContext {
        PerpsMarketScreenContext(market: market, markPrice: markPrice, lifecycle: lifecycle)
    }
}

import TKTradingAPI

public enum PerpsMarketsSort: CaseIterable, Sendable {
    case volume
    case priceChange
    case openInterest
}

extension PerpsMarketsSort {
    var tradingApiValue: Components.Schemas.AssetsSort {
        switch self {
        case .volume:
            .volume_24h
        case .priceChange:
            .price_24h
        case .openInterest:
            .open_interest_usd
        }
    }
}

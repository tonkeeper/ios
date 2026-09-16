import TKTradingAPI

public enum TradingAssetCategory: String, CaseIterable, Identifiable, Sendable {
    case all
    case tokens
    case stocks
    case etfs

    public var id: String {
        rawValue
    }
}

extension TradingAssetCategory {
    init?(tradingApiValue: Components.Schemas.AssetsTab) {
        switch tradingApiValue {
        case .all:
            self = .all
        case .tokens:
            self = .tokens
        case .stocks:
            self = .stocks
        case .etfs:
            self = .etfs
        case .commodities, .perpetuals:
            return nil
        }
    }

    var tradingApiValue: Components.Schemas.AssetsTab {
        switch self {
        case .all:
            .all
        case .tokens:
            .tokens
        case .stocks:
            .stocks
        case .etfs:
            .etfs
        }
    }
}

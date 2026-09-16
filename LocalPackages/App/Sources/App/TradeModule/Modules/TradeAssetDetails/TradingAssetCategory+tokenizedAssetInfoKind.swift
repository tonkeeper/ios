import KeeperCore

extension TradingAssetCategory {
    var tokenizedAssetInfoKind: TokenizedAssetInfoKind? {
        switch self {
        case .stocks:
            return .stock
        case .etfs:
            return .etf
        case .all, .tokens:
            return nil
        }
    }
}

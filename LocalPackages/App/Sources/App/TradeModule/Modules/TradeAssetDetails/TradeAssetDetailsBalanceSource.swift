import KeeperCore

enum TradeAssetDetailsBalanceSource {
    case legacyStore(TradingAssetToken)
    case multichain

    init(typedAssetId: TradingAssetToken?, wallet: Wallet) {
        guard let typedAssetId else {
            self = .multichain
            return
        }
        switch typedAssetId {
        case .tronUsdt where wallet.isMultichain, .tronTrx where wallet.isMultichain:
            self = .multichain
        case .ton, .jetton, .tronUsdt, .tronTrx:
            self = .legacyStore(typedAssetId)
        }
    }
}

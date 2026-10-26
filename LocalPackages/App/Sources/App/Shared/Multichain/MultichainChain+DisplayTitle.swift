import KeeperCore
import TKLocalize

extension MultichainChain {
    var shortDisplayTitle: String {
        switch self {
        case .ton:
            return TKLocales.Receive.Multichain.Networks.Ton.title
        case .eth:
            return TKLocales.Receive.Multichain.Networks.Ethereum.title
        case .btc:
            return TKLocales.Receive.Multichain.Networks.Bitcoin.title
        case .base:
            return TKLocales.Receive.Multichain.Networks.Base.title
        case .bsc:
            return TKLocales.Receive.Multichain.Networks.Smartchain.title
        case .arb:
            return TKLocales.Receive.Multichain.Networks.Arbitrum.title
        case .tron:
            return TKLocales.Receive.Multichain.Networks.Tron.title
        case .sol:
            return TKLocales.Receive.Multichain.Networks.Solana.title
        case .polygon:
            return TKLocales.Receive.Multichain.Networks.Polygon.title
        case .avax:
            return TKLocales.Receive.Multichain.Networks.Avalanche.title
        case .robinhood:
            return TKLocales.Receive.Multichain.Networks.Robinhood.title
        }
    }

    var displayTitle: String {
        switch self {
        case .ton:
            return TKLocales.Receive.Multichain.Networks.Ton.displayTitle
        case .eth:
            return TKLocales.Receive.Multichain.Networks.Ethereum.displayTitle
        case .btc:
            return TKLocales.Receive.Multichain.Networks.Bitcoin.displayTitle
        case .base:
            return TKLocales.Receive.Multichain.Networks.Base.displayTitle
        case .bsc:
            return TKLocales.Receive.Multichain.Networks.Smartchain.displayTitle
        case .arb:
            return TKLocales.Receive.Multichain.Networks.Arbitrum.displayTitle
        case .tron:
            return TKLocales.Receive.Multichain.Networks.Tron.displayTitle
        case .sol:
            return TKLocales.Receive.Multichain.Networks.Solana.displayTitle
        case .polygon:
            return TKLocales.Receive.Multichain.Networks.Polygon.displayTitle
        case .avax:
            return TKLocales.Receive.Multichain.Networks.Avalanche.displayTitle
        case .robinhood:
            return TKLocales.Receive.Multichain.Networks.Robinhood.displayTitle
        }
    }
}

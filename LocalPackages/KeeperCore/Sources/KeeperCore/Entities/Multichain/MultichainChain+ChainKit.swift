import ChainKit

extension MultichainChain {
    var asChainKitChain: Chain {
        switch self {
        case .ton:
            return ChainTonMainnet.shared
        case .eth:
            return ChainEthereumMainnet.shared
        case .base:
            return ChainBaseMainnet.shared
        case .btc:
            return ChainBitcoinMainnet.shared
        case .tron:
            return ChainTronMainnet.shared
        case .arb:
            return ChainArbitrumMainnet.shared
        case .bsc:
            return ChainSmartchainMainnet.shared
        }
    }

    public var isLayer1: Bool {
        asChainKitChain.coin.primaryCoin == nil
    }
}

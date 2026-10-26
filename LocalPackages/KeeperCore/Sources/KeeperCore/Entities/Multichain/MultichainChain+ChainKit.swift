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
        case .sol:
            return ChainSolanaMainnet.shared
        case .polygon:
            return ChainPolygonMainnet.shared
        case .avax:
            return ChainAvalancheMainnet.shared
        case .robinhood:
            return ChainRobinhoodMainnet.shared
        }
    }

    public var isLayer1: Bool {
        asChainKitChain.coin.primaryCoin == nil
    }

    /// The chain as the battery's relayer spells it, `eth/mainnet`; CAIP-2 (`eip155:1`) is rejected there.
    var relayerChainId: String {
        let network = asChainKitChain.network
        return "\(network.type.id)/\(network.mode.id)"
    }

    init?(relayerChainId: String) {
        guard let chain = MultichainChain.allCases.first(where: { $0.relayerChainId == relayerChainId }) else {
            return nil
        }
        self = chain
    }
}

public extension MultichainChain {
    var eip155ChainId: Int? {
        switch self {
        case .eth: 1
        case .base: 8453
        case .arb: 42161
        case .bsc: 56
        case .ton, .btc, .tron: nil
        }
    }

    var isEVM: Bool {
        eip155ChainId != nil
    }

    init?(eip155ChainId: Int) {
        guard let chain = MultichainChain.allCases.first(where: { $0.eip155ChainId == eip155ChainId }) else {
            return nil
        }
        self = chain
    }
}

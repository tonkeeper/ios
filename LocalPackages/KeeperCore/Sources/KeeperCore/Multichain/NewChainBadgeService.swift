public protocol NewChainBadgeService {
    func shouldShowBadge(for chain: MultichainChain) -> Bool
}

struct NewChainBadgeServiceImplementation: NewChainBadgeService {
    private let newChains: Set<MultichainChain> = [.sol, .polygon, .avax, .robinhood]

    func shouldShowBadge(for chain: MultichainChain) -> Bool {
        newChains.contains(chain)
    }
}

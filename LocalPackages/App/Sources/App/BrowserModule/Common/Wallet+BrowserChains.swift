import KeeperCore

extension Wallet {
    func browserChains(order: [MultichainChain]) -> [MultichainChain] {
        guard let state = multichainWalletState else { return [.ton] }
        let chains = Set(state.addresses.map(\.chain))
        return order.filter(chains.contains)
    }
}

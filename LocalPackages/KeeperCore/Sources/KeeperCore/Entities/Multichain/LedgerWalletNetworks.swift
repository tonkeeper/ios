import Foundation

extension MultichainWalletState {
    /// The state of a multichain Ledger wallet with the addresses `keys` reach on the chains of `chains` it has none
    /// on, in display order, and those chains; `nil` when the keys add none. It is registered before it is saved,
    /// hence synced.
    func addingLedgerNetworks(_ keys: LedgerAppKeys, chains: [MultichainChain]) throws -> (state: MultichainWalletState, added: [MultichainChain])? {
        let added = try keys.addresses(chains: chains).filter { address in
            !addresses.contains { $0.chain == address.chain }
        }
        guard !added.isEmpty else {
            return nil
        }
        let state = MultichainWalletState(
            walletId: walletId,
            addresses: (addresses + added).sorted { $0.chain.displayOrderIndex < $1.chain.displayOrderIndex },
            syncState: .synced
        )
        return (state, added.map(\.chain))
    }
}

extension LedgerMultichainAccount {
    /// What a TON-only Ledger wallet becomes in place: its wallet seed and app key, its state and the chains it gains
    /// besides TON; `nil` when it would gain none, so that the wallet stays as it is.
    func upgrade(
        tonPublicKey: Data,
        chains: [MultichainChain]
    ) throws -> (seed: Data, appPrivateKey: Data, state: MultichainWalletState, added: [MultichainChain])? {
        let (seed, appPrivateKey, state) = try wallet(tonPublicKey: tonPublicKey, chains: chains)
        let added = state.addresses.map(\.chain).filter { $0 != .ton }
        return added.isEmpty ? nil : (seed, appPrivateKey, state, added)
    }
}

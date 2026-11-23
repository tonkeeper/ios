public extension Wallet {
    /// The Earn backend checks the wallet proof against the wallet's registration with the
    /// multichain backend, so a wallet is asked about only once it has synced there.
    var earnWalletId: String? {
        guard isMultichainDappsAvailable, let state = multichainWalletState, state.syncState == .synced else { return nil }
        return state.walletId
    }
}

import TKFeatureFlags

public extension Wallet {
    var isMultichain: Bool {
        multichainWalletState != nil
    }

    var multichainWalletState: MultichainWalletState? {
        guard case let .multichain(state) = multichain,
              !state.addresses.isEmpty
        else {
            return nil
        }
        return state
    }

    /// WalletConnect and Earn sign through ChainKit: in the app with the mnemonic, or on a multichain Ledger.
    var isMultichainDappsAvailable: Bool {
        isMultichain && (kind == .regular || kind == .ledger)
    }

    /// Perps and moving legacy wallets into this one sign with the mnemonic of a multichain wallet.
    var hasMultichainMnemonic: Bool {
        isMultichain && kind == .regular
    }

    var multichainWalletId: String? {
        multichainWalletState?.walletId
    }

    var multichainEthereumAddress: String? {
        multichainWalletState?.addresses.first { $0.chain == .eth }?.address
    }
}

public extension Configuration {
    /// Swaps, WalletConnect and Earn of a multichain Ledger roll out with it, behind `ledgerMultichain`: with the flag
    /// off they stay closed to it, and what it would sign on the device reports itself unavailable.
    func isLedgerDappsLocked(_ wallet: Wallet) -> Bool {
        wallet.kind == .ledger && wallet.isMultichain && !featureEnabled(.ledgerMultichain)
    }

    /// WalletConnect and Earn are open to `wallet`: it can sign them, and their rollout has reached it.
    func isMultichainDappsAvailable(_ wallet: Wallet) -> Bool {
        wallet.isMultichainDappsAvailable && !isLedgerDappsLocked(wallet)
    }
}

/// The wallet as the multichain swap sees it: the addresses it swaps between, whether the backend
/// knows it under a wallet id, and the keys it signs with. Its mnemonic, battery, balances and
/// network stay on `wallet`.
public struct MultichainSwapWallet {
    @frozen public enum Registration: Hashable {
        /// Registered on the multichain backend, which files the wallet's swaps under this id.
        case registered(walletId: String)
        /// Known only locally: quotes and routes go out without a wallet id and no swap is reported.
        case unregistered
    }

    @frozen public enum Keys: Hashable {
        /// The BIP39 HD wallet a multichain wallet derives every chain's key from.
        case hd
        /// The keys a legacy wallet's TON and TRON addresses were created with.
        case legacy
    }

    public let wallet: Wallet
    public let addresses: [MultichainWalletAddress]
    public let registration: Registration
    public let keys: Keys

    public init(
        wallet: Wallet,
        addresses: [MultichainWalletAddress],
        registration: Registration,
        keys: Keys
    ) {
        self.wallet = wallet
        self.addresses = addresses
        self.registration = registration
        self.keys = keys
    }

    /// A wallet registered on the multichain backend swaps on the state the backend filed.
    public init(wallet: Wallet, registeredState state: MultichainWalletState) {
        self.init(
            wallet: wallet,
            addresses: state.addresses,
            registration: .registered(walletId: state.walletId),
            keys: .hd
        )
    }

    public var walletId: String? {
        switch registration {
        case let .registered(walletId):
            return walletId
        case .unregistered:
            return nil
        }
    }

    public func walletAddress(for chain: MultichainChain) -> MultichainWalletAddress? {
        addresses.walletAddress(
            for: chain,
            preferredType: wallet.preferredMultichainAddressType(for: chain)
        )
    }

    public func address(for chain: MultichainChain) -> String? {
        walletAddress(for: chain)?.address
    }
}

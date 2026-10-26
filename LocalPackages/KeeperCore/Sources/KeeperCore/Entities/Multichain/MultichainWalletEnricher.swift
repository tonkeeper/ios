import Foundation
import KeeperCoreSensitive
import TKLogging

public protocol MultichainWalletEnricher {
    var needsStartupEnrichment: Bool { get }
    /// Supported chains a wallet that already holds multichain addresses has none for, in display
    /// order: what the new networks screen adds. Empty once every such wallet has them all.
    var missingChains: [MultichainChain] { get }
    func enrichMissingWallets(passcode: String) async
}

// MARK: -

struct MultichainWalletEnricherDependencies {
    var supportedChains: Set<MultichainChain>
    var getWallets: () -> [Wallet]
    var getMnemonics: (_ wallets: [Wallet], _ passcode: String) async throws -> [CoreMnemonicIdentifier: CoreMnemonic]
    var deriveWallet: (_ mnemonic: String) throws -> MultichainWalletState
    var syncWallet: (_ mnemonic: String, _ state: MultichainWalletState) async throws(MultichainServiceError) -> Void
    var saveWallet: (_ wallet: Wallet, _ multichain: MultichainWallet) async -> Void
}

struct MultichainWalletEnricherImplementation {
    private let dependencies: MultichainWalletEnricherDependencies
    private let sleep: MultichainRetry.Sleep

    init(
        dependencies: MultichainWalletEnricherDependencies,
        sleep: @escaping MultichainRetry.Sleep = MultichainRetry.defaultSleep
    ) {
        self.dependencies = dependencies
        self.sleep = sleep
    }
}

extension MultichainWalletEnricherImplementation: MultichainWalletEnricher {
    var needsStartupEnrichment: Bool {
        !walletsNeedingEnrichment().isEmpty
    }

    var missingChains: [MultichainChain] {
        let missing = dependencies.getWallets().reduce(into: Set<MultichainChain>()) { missing, wallet in
            guard wallet.isMainnetRegular, let state = wallet.multichainWalletState else { return }
            missing.formUnion(missingChains(in: state.addresses, for: wallet))
        }
        return MultichainChain.displayOrder.filter(missing.contains)
    }

    func enrichMissingWallets(passcode: String) async {
        await enrich(walletsNeedingEnrichment(), passcode: passcode)
    }
}

private extension MultichainWalletEnricherImplementation {
    func enrich(_ wallets: [Wallet], passcode: String) async {
        guard !wallets.isEmpty else {
            return
        }
        let mnemonicsByWalletId: [CoreMnemonicIdentifier: CoreMnemonic]
        do {
            mnemonicsByWalletId = try await dependencies.getMnemonics(wallets, passcode)
        } catch {
            Log.multichain.e("failed to load mnemonics for multichain enrichment", error: error)
            return
        }
        for wallet in wallets {
            do {
                guard let mnemonic = mnemonicsByWalletId[wallet.id] else {
                    Log.multichain.e(
                        "failed to enrich multichain wallet due to missing mnemonic",
                        error: MultichainLoggingError.missingMnemonic(operation: "enrichment"),
                        extraInfo: enrichmentInfo(for: wallet)
                    )
                    continue
                }
                let phrase = mnemonic.mnemonicWords.joined(separator: " ")
                let multichainWallet = try persistedMultichainWallet(
                    for: wallet,
                    from: mnemonic,
                    phrase: phrase
                )
                guard multichainWallet != wallet.multichain else {
                    continue
                }
                if let registered = wallet.registeredMultichainState,
                   case let .multichain(derived) = multichainWallet,
                   derived.walletId == registered.walletId
                {
                    try await registerAndSave(derived, for: wallet, phrase: phrase)
                } else {
                    await dependencies.saveWallet(wallet, multichainWallet)
                }
            } catch {
                // A pass without a connection has had its retries and gets another on the next
                // launch; only the other failures are worth a non-fatal.
                if (error as? any MultichainTransientError)?.isTransient == true {
                    Log.multichain.w(
                        "failed to enrich multichain wallet",
                        error: error,
                        extraInfo: enrichmentInfo(for: wallet)
                    )
                } else {
                    Log.multichain.e(
                        "failed to enrich multichain wallet",
                        error: error,
                        extraInfo: enrichmentInfo(for: wallet)
                    )
                }
            }
        }
    }

    /// What the failed pass was adding: the chains, and whether they went to a wallet the backend
    /// already knows — the new networks screen's case — or to one being enriched for the first time.
    func enrichmentInfo(for wallet: Wallet) -> [String: String] {
        let chains = missingChains(in: wallet.multichainWalletState?.addresses ?? [], for: wallet)
        return [
            "chains": MultichainChain.displayOrder.filter(chains.contains).map(\.rawValue).joined(separator: ","),
            "registered": String(wallet.registeredMultichainState != nil),
        ]
    }

    /// A wallet the backend already knows keeps its state until the backend has accepted the new
    /// addresses. Saved first, a failed registration would mark it `.failed`, which hides the
    /// perps section and drops it from push bindings; left as is, the chains stay missing and the
    /// next launch retries them.
    func registerAndSave(
        _ derived: MultichainWalletState,
        for wallet: Wallet,
        phrase: String
    ) async throws(MultichainServiceError) {
        try await MultichainRetry.run(sleep: sleep) { () async throws(MultichainServiceError) in
            try await dependencies.syncWallet(phrase, derived)
        }
        await dependencies.saveWallet(
            wallet,
            .multichain(
                MultichainWalletState(
                    walletId: derived.walletId,
                    addresses: derived.addresses,
                    syncState: .synced
                )
            )
        )
    }

    func persistedMultichainWallet(
        for wallet: Wallet,
        from mnemonic: CoreMnemonic,
        phrase: String
    ) throws -> MultichainWallet {
        switch mnemonic.type {
        case .bip39:
            let state = try dependencies.deriveWallet(phrase)
            let addresses = state.addresses.filter { address in
                guard dependencies.supportedChains.contains(address.chain) else {
                    return false
                }
                guard address.chain == .ton else {
                    return true
                }
                return address.type == wallet.preferredMultichainAddressType(for: .ton)
            }
            return .multichain(
                MultichainWalletState(
                    walletId: state.walletId,
                    addresses: addresses,
                    syncState: .pending
                )
            )
        default:
            return .unavailable
        }
    }

    func walletsNeedingEnrichment() -> [Wallet] {
        dependencies.getWallets().filter { wallet in
            guard wallet.isMainnetRegular else {
                return false
            }
            let addresses: [MultichainWalletAddress]
            switch wallet.multichain {
            case .unavailable:
                return false
            case let .multichain(state):
                addresses = state.addresses
            case nil:
                addresses = []
            }
            return !missingChains(in: addresses, for: wallet).isEmpty
        }
    }

    func missingChains(
        in addresses: [MultichainWalletAddress],
        for wallet: Wallet
    ) -> Set<MultichainChain> {
        dependencies.supportedChains.filter { chain in
            let address: MultichainWalletAddress?
            switch chain {
            case .ton:
                guard let preferredType = wallet.preferredMultichainAddressType(for: .ton) else {
                    return false
                }
                address = addresses.first { $0.chain == .ton && $0.type == preferredType }
            case .btc:
                address = addresses.first { $0.chain == .btc && $0.type == .btcP2WPKH }
            case .eth, .base, .tron, .arb, .bsc, .sol, .polygon, .avax, .robinhood:
                address = addresses.first { $0.chain == chain }
            }
            return address?.publicKey == nil
        }
    }
}

private extension Wallet {
    var isMainnetRegular: Bool {
        kind == .regular && network == .mainnet
    }

    /// The state the backend has accepted: synced, with addresses.
    var registeredMultichainState: MultichainWalletState? {
        guard let state = multichainWalletState, state.syncState == .synced else {
            return nil
        }
        return state
    }
}

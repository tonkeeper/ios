import Foundation
import KeeperCoreSensitive
import TKLogging

public protocol MultichainWalletEnricher {
    var needsStartupEnrichment: Bool { get }
    func enrichMissingWallets(passcode: String) async
}

// MARK: -

struct MultichainWalletEnricherDependencies {
    var supportedChains: Set<MultichainChain>
    var getWallets: () -> [Wallet]
    var getMnemonics: (_ wallets: [Wallet], _ passcode: String) async throws -> [CoreMnemonicIdentifier: CoreMnemonic]
    var deriveWallet: (_ mnemonic: String) throws -> MultichainWalletState
    var saveWallet: (_ wallet: Wallet, _ multichain: MultichainWallet) async -> Void
}

struct MultichainWalletEnricherImplementation {
    private let dependencies: MultichainWalletEnricherDependencies

    init(dependencies: MultichainWalletEnricherDependencies) {
        self.dependencies = dependencies
    }
}

extension MultichainWalletEnricherImplementation: MultichainWalletEnricher {
    var needsStartupEnrichment: Bool {
        !walletsNeedingEnrichment().isEmpty
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
            Log.w("failed to load mnemonics for multichain enrichment", error: error)
            return
        }
        for wallet in wallets {
            do {
                guard let mnemonic = mnemonicsByWalletId[wallet.id] else {
                    Log.w(
                        "failed to enrich multichain wallet due to missing mnemonic",
                        error: MultichainLoggingError.missingMnemonic(operation: "enrichment")
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
                await dependencies.saveWallet(wallet, multichainWallet)
            } catch {
                Log.w(
                    "failed to enrich multichain wallet",
                    error: error
                )
            }
        }
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
            guard wallet.kind == .regular, wallet.network == .mainnet else {
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
            return hasMissingRequiredAccounts(addresses, for: wallet)
        }
    }

    func hasMissingRequiredAccounts(
        _ addresses: [MultichainWalletAddress],
        for wallet: Wallet
    ) -> Bool {
        dependencies.supportedChains.contains { chain in
            let address: MultichainWalletAddress?
            switch chain {
            case .ton:
                guard let preferredType = wallet.preferredMultichainAddressType(for: .ton) else {
                    return false
                }
                address = addresses.first { $0.chain == .ton && $0.type == preferredType }
            case .btc:
                address = addresses.first { $0.chain == .btc && $0.type == .btcP2WPKH }
            case .eth, .base, .tron, .arb, .bsc:
                address = addresses.first { $0.chain == chain }
            }
            return address?.publicKey == nil
        }
    }
}

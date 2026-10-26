import Foundation
import KeeperCoreSensitive

/// QA tool for the new networks screen: re-registers a wallet without `chains` and drops their
/// addresses, so they count as missing again and the next launch adds them back.
public struct MultichainWalletChainRemover {
    @frozen public enum Error: Swift.Error {
        case notMultichain
        case missingMnemonic
    }

    struct Dependencies {
        var getMnemonics: (_ wallets: [Wallet], _ passcode: String) async throws -> [CoreMnemonicIdentifier: CoreMnemonic]
        var syncWallet: (_ mnemonic: String, _ state: MultichainWalletState) async throws(MultichainServiceError) -> Void
        var saveWallet: (_ wallet: Wallet, _ multichain: MultichainWallet) async -> Void
    }

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func remove(_ chains: Set<MultichainChain>, from wallet: Wallet, passcode: String) async throws {
        guard let state = wallet.multichainWalletState else {
            throw Error.notMultichain
        }
        let remaining = state.addresses.filter { !chains.contains($0.chain) }
        guard remaining.count < state.addresses.count else {
            return
        }
        guard let mnemonic = try await dependencies.getMnemonics([wallet], passcode)[wallet.id] else {
            throw Error.missingMnemonic
        }
        let reduced = MultichainWalletState(
            walletId: state.walletId,
            addresses: remaining,
            syncState: .synced
        )
        try await dependencies.syncWallet(mnemonic.mnemonicWords.joined(separator: " "), reduced)
        await dependencies.saveWallet(wallet, .multichain(reduced))
    }
}

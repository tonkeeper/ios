import ChainKit
import Foundation

struct WalletConnectSigningContext {
    let passcodeProvider: () async -> String?
    let wallet: Wallet
    let mnemonicAccess: MnemonicAccess
    let client: CryptoKitClient
    let pendingTransactionsService: PendingTransactionsService

    func reportPendingTransaction(
        chain: WalletConnectChain,
        txHash: String,
        activityType: MultichainPendingTransaction.ActivityType
    ) async {
        await pendingTransactionsService.record(
            .chain(
                chain.multichainChain,
                wallet: wallet,
                txHashes: [txHash],
                activityType: activityType
            ),
            wallet: wallet
        )
    }

    func cryptoWallet() async throws(WalletConnectSigningError) -> CryptoWallet {
        guard let passcode = await passcodeProvider() else {
            throw .canceled
        }

        do {
            let mnemonic = try await mnemonicAccess.getMnemonic(
                wallet: wallet,
                passcode: passcode
            )
            return try CryptoWallet.Companion.shared.fromMnemonic(
                mnemonic_: mnemonic.mnemonicWords.joined(separator: " ")
            )
        } catch {
            throw .mnemonic(reason: "failed to read mnemonic for WalletConnect: \(error.logDescription)")
        }
    }

    func accountAddress(
        chain: WalletConnectChain
    ) throws(WalletConnectSigningError) -> String {
        let multichainChain = chain.multichainChain
        let preferredType = wallet.preferredMultichainAddressType(for: multichainChain)
        guard case let .multichain(state) = wallet.multichain,
              let address = state.address(for: multichainChain, preferredType: preferredType)
        else {
            throw .missingMultichainAddress(chain: chain, walletId: wallet.id)
        }
        return address
    }

    func validateSameAddress(
        expected: String,
        actual: String
    ) throws(WalletConnectSigningError) {
        let lhs = expected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhs = actual.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lhs == rhs else {
            throw .senderAddressMismatch(expected: expected, actual: actual)
        }
    }

    func validateAddress(
        _ address: String?,
        chain: WalletConnectChain
    ) throws(WalletConnectSigningError) {
        guard let address, !address.isEmpty else {
            return
        }
        try validateSameAddress(
            expected: accountAddress(chain: chain),
            actual: address
        )
    }
}

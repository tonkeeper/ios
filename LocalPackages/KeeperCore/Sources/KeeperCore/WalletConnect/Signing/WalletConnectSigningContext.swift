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

    func chainKitAccount(
        chain: WalletConnectChain,
        cryptoWallet: CryptoWallet
    ) throws(WalletConnectSigningError) -> ChainKit.Account {
        let chainKitChain = chain.multichainChain.asChainKitChain
        let addressString = try accountAddress(chain: chain)
        guard let address = Address.Companion.shared.from(value: addressString, chain: chainKitChain, type: .default_) else {
            throw .invalidTransaction(reason: "invalid sender address: \(addressString)")
        }
        return ChainKit.Account(
            address: address,
            asset: chainKitChain.toAsset(),
            derivation: DerivationDefaultPath.shared,
            publicKey: cryptoWallet.getPublicKey(chain: chainKitChain)
        )
    }

    func validateSameAddress(
        expected: String,
        actual: String,
        chain: WalletConnectChain
    ) throws(WalletConnectSigningError) {
        let lhs = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = actual.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSame = chain.eip155ChainId != nil
            ? lhs.caseInsensitiveCompare(rhs) == .orderedSame
            : lhs == rhs
        guard isSame else {
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
            actual: address,
            chain: chain
        )
    }
}

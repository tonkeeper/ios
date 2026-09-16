import ChainKit

/// Unlocks the wallet used to sign a swap: asks the user for a passcode, reads the
/// mnemonic and derives the multichain `CryptoWallet` that signs every payload of
/// the route. Kept separate so key material handling stays in one place.
struct SwapWalletUnlocker {
    let mnemonicAccess: MnemonicAccess

    func unlockSigningWallet(
        passcodeProvider: () async -> String?,
        wallet: Wallet
    ) async throws(MultichainSwapExecutionFailure) -> CryptoWallet {
        guard let passcode = await passcodeProvider() else {
            throw .canceled
        }
        let phrase: String
        do {
            let coreMnemonic = try await mnemonicAccess.getMnemonic(
                wallet: wallet,
                passcode: passcode
            )
            phrase = coreMnemonic.mnemonicWords.joined(separator: " ")
        } catch {
            throw .internal(reason: "failed to read mnemonic during multichain swap due to error: \(error.logDescription)")
        }
        do {
            return try CryptoWallet.Companion.shared.fromMnemonic(
                mnemonic_: normalized(mnemonic: phrase)
            )
        } catch {
            throw .internal(reason: "failed to derive multichain wallet: \(error.logDescription)")
        }
    }

    private func normalized(mnemonic: String) -> String {
        mnemonic
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

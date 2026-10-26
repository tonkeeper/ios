import ChainKit
import KeeperCoreSensitive
import TronSwift

/// Unlocks the wallet used to sign a swap: asks the user for a passcode, reads the
/// mnemonic and derives the keys that sign every payload of the route. Kept separate
/// so key material handling stays in one place.
struct SwapWalletUnlocker {
    let mnemonicAccess: MnemonicAccess

    func unlockSigningWallet(
        passcodeProvider: () async -> String?,
        swapWallet: MultichainSwapWallet
    ) async throws(MultichainSwapExecutionFailure) -> SwapSigningWallet {
        guard let passcode = await passcodeProvider() else {
            throw .canceled
        }
        let coreMnemonic: CoreMnemonic
        do {
            coreMnemonic = try await mnemonicAccess.getMnemonic(
                wallet: swapWallet.wallet,
                passcode: passcode
            )
        } catch {
            throw .internal(reason: "failed to read mnemonic during multichain swap due to error: \(error.logDescription)")
        }
        switch swapWallet.keys {
        case .legacy:
            return try SwapSigningWallet(
                legacyMnemonic: coreMnemonic,
                tronAddress: legacyTronAddress(of: swapWallet)
            )
        case .hd:
            do {
                return try .hd(
                    CryptoWallet.Companion.shared.fromMnemonic(
                        mnemonic_: normalized(mnemonic: coreMnemonic.mnemonicWords.joined(separator: " "))
                    )
                )
            } catch {
                throw .internal(reason: "failed to derive multichain wallet: \(error.logDescription)")
            }
        }
    }

    private func legacyTronAddress(
        of swapWallet: MultichainSwapWallet
    ) throws(MultichainSwapExecutionFailure) -> TronSwift.Address {
        guard let address = swapWallet.address(for: .tron) else {
            throw .internal(reason: "a legacy wallet without a TRON address cannot sign a swap")
        }
        do {
            return try TronSwift.Address(address: address)
        } catch {
            throw .internal(reason: "a legacy wallet has an unusable TRON address: \(error.logDescription)")
        }
    }

    private func normalized(mnemonic: String) -> String {
        mnemonic
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

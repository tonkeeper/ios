import BigInt
import ChainKit
import Foundation
import OperationReviewModels
import TKLogging

public protocol ChainKitService {
    func isTransferSupported(asset: MultichainAsset) -> Bool

    func tronPrivateKey(mnemonic: String) throws -> Data

    func makeBatterySendProof(
        mnemonic: String,
        walletId: String,
        boc: String
    ) throws -> String

    /// The wallet's app key, which signs everything scoped to that one wallet. Held by the caller
    /// so a token can be minted again without the mnemonic, and therefore without a passcode.
    func walletAppPrivateKey(mnemonic: String) throws -> Data

    /// Signs `accessToken` with the wallet's app key, producing the `X-Wallet-Authorization`
    /// credential. The token is only valid for the access token it signs; `nil` when the key is not
    /// the app key of `walletId`.
    func walletAuthToken(appPrivateKey: Data, walletId: String, accessToken: String) -> String?

    /// `commentEncryptionKey`, the recipient's TON public key in hex, sends the comment of a TON coin
    /// transfer encrypted to it: priced as a stand-in of its size, encrypted once the wallet is unlocked.
    func emulateTransaction(
        wallet: Wallet,
        recipient: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        commentEncryptionKey: String?,
        isMaxAmount: Bool
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult

    /// `consent` answers what the review of the transfer about to be signed asks.
    func sendMultichainTransfer(
        signer: MultichainTransferSigner,
        wallet: Wallet,
        recipient: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        commentEncryptionKey: String?,
        isMaxAmount: Bool,
        consent: OperationConsent
    ) async throws(MultichainTransactionFailure) -> [String]

    /// The transfer as chain-kit's own operation for it, priced and reviewed as that operation: the
    /// one `sendOperationTransfer` signs, at this fee.
    func emulateOperationTransfer(
        wallet: Wallet,
        recipient: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        commentEncryptionKey: String?,
        isMaxAmount: Bool
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult

    /// Signs the operation `emulation` priced, at the fee it priced, with the wallet's mnemonic, and
    /// sends it. `consent` answers what its review asks, before the passcode is asked for.
    func sendOperationTransfer(
        _ emulation: MultichainTransactionEmulationResult,
        wallet: Wallet,
        passcodeProvider: @escaping () async -> String?,
        consent: OperationConsent
    ) async throws(MultichainTransactionFailure) -> [String]

    func makeWalletState(mnemonic: String) throws -> MultichainWalletState

    func makeWalletRegisterItem(
        appPrivateKey: Data,
        deviceId: String,
        challenge: String,
        state: MultichainWalletState
    ) throws -> MultichainWalletRegisterItem

    func makeMnemonic() throws(MultichainMakeMnemonicFailure) -> [String]
}

public extension ChainKitService {
    /// The proof is read only when the transfer goes out on the battery, and the backend accepts a
    /// message without one, so a failure here must not fail the send — it is logged instead of
    /// swallowed so a systematic breakage is visible rather than silent.
    func batterySendProof(wallet: Wallet, mnemonic: String, boc: String) -> String? {
        guard let walletId = wallet.multichainWalletState?.walletId, !walletId.isEmpty else {
            return nil
        }
        do {
            return try makeBatterySendProof(mnemonic: mnemonic, walletId: walletId, boc: boc)
        } catch {
            Log.w("failed to build battery send proof", error: error)
            return nil
        }
    }
}

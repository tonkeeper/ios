import BigInt
import ChainKit
import Foundation
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
    /// credential. The token is only valid for the access token it signs.
    func walletAuthToken(appPrivateKey: Data, accessToken: String) -> String

    func emulateTransaction(
        wallet: Wallet,
        recipient: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool
    ) async throws(MultichainTransactionEmulationFailure) -> MultichainTransactionEmulationResult

    func sendMultichainTransfer(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        recipient: String,
        asset: MultichainAsset,
        amount: BigUInt,
        comment: String?,
        isMaxAmount: Bool
    ) async throws(MultichainTransactionFailure) -> [String]

    func makeWalletState(mnemonic: String) throws -> MultichainWalletState

    func makeWalletRegisterItem(
        mnemonic: String,
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

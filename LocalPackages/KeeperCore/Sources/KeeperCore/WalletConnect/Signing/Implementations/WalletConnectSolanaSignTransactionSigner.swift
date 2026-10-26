import Foundation
import TKLogging

struct WalletConnectSolanaSignTransactionSigner: WalletConnectRequestPayloadSigner {
    private let utilities = WalletConnectSolanaSigningUtilities()

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .solanaTransaction(transaction, send) = request.payload else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires solana transaction payload")
        }

        try context.validateAddress(transaction.pubkey, chain: .sol)
        let cryptoWallet = try await context.cryptoWallet()
        let signed = try await utilities.signTransaction(
            transaction.transaction,
            client: context.client,
            cryptoWallet: cryptoWallet
        )
        guard send else {
            return .object([
                "signature": signed.signature,
                "transaction": signed.transaction,
            ])
        }

        do {
            let signature = try await utilities.send(
                signed.transaction,
                client: context.client,
                account: context.chainKitAccount(chain: .sol, cryptoWallet: cryptoWallet)
            )
            await context.reportPendingTransaction(
                chain: .sol,
                txHash: signature,
                activityType: .contractCall
            )
            return .object(["signature": signature])
        } catch {
            Log.walletConnect.w("solana transaction send failed", error: error)
            throw error
        }
    }
}

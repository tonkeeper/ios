@preconcurrency import AnyCodable
import Foundation

struct WalletConnectSolanaSignAllTransactionsSigner: WalletConnectRequestPayloadSigner {
    private let utilities = WalletConnectSolanaSigningUtilities()

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .solanaTransactionBatch(batch) = request.payload else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires solana transactions payload")
        }

        try context.validateAddress(batch.pubkey, chain: .sol)
        let cryptoWallet = try await context.cryptoWallet()
        var signedTransactions = [String]()
        for transaction in batch.transactions {
            let signed = try await utilities.signTransaction(
                transaction,
                client: context.client,
                cryptoWallet: cryptoWallet
            )
            signedTransactions.append(signed.transaction)
        }
        return .json(AnyCodable(["transactions": signedTransactions]))
    }
}

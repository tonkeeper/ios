import Foundation

struct WalletConnectEthSendTransactionSigner: WalletConnectRequestPayloadSigner {
    private let utilities = WalletConnectEVMTransactionSigningUtilities()

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .evmTransaction(transaction, send) = request.payload,
              send
        else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires send EVM transaction payload")
        }

        return try await utilities.sign(
            transaction: transaction,
            send: true,
            chain: request.chain,
            context: context
        )
    }
}

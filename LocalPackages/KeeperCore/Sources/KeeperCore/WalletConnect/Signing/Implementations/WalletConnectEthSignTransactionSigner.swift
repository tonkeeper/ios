import Foundation

struct WalletConnectEthSignTransactionSigner: WalletConnectRequestPayloadSigner {
    private let utilities = WalletConnectEVMTransactionSigningUtilities()

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .evmTransaction(transaction, send) = request.payload,
              !send
        else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires sign-only EVM transaction payload")
        }

        return try await utilities.sign(
            transaction: transaction,
            send: false,
            chain: request.chain,
            context: context
        )
    }
}

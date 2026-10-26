import Foundation

struct WalletConnectSolanaSignMessageSigner: WalletConnectRequestPayloadSigner {
    private let utilities = WalletConnectSolanaSigningUtilities()

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .signMessage(message) = request.payload,
              case .solana = message.kind
        else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires solana sign message payload")
        }

        try context.validateAddress(message.address, chain: .sol)
        let cryptoWallet = try await context.cryptoWallet()
        let signature = try await utilities.signMessage(
            message.message,
            client: context.client,
            cryptoWallet: cryptoWallet
        )
        return .object(["signature": signature])
    }
}

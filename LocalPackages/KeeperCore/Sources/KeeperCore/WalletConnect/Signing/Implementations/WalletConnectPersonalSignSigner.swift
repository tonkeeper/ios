import Foundation

struct WalletConnectPersonalSignSigner: WalletConnectRequestPayloadSigner {
    private let utilities = WalletConnectChainKitMessageSigningUtilities()

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .signMessage(message) = request.payload,
              case .personal = message.kind
        else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires personal sign message payload")
        }

        try context.validateAddress(message.address, chain: request.chain)
        let cryptoWallet = try await context.cryptoWallet()
        let signature = try await utilities.sign(
            client: context.client,
            chain: request.chain,
            cryptoWallet: cryptoWallet,
            message: message.message,
            kind: .personal
        )
        return .string(signature)
    }
}

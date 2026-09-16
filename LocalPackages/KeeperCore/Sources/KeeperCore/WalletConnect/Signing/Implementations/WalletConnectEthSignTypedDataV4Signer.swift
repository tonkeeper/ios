import Foundation

struct WalletConnectEthSignTypedDataV4Signer: WalletConnectRequestPayloadSigner {
    private let utilities = WalletConnectChainKitMessageSigningUtilities()

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .signMessage(message) = request.payload,
              case .typedDataV4 = message.kind
        else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires typed data sign message payload")
        }

        try context.validateAddress(message.address, chain: request.chain)
        let cryptoWallet = try await context.cryptoWallet()
        let signature = try await utilities.sign(
            client: context.client,
            chain: request.chain,
            cryptoWallet: cryptoWallet,
            message: message.message,
            kind: .typedDataV4
        )
        return .string(signature)
    }
}

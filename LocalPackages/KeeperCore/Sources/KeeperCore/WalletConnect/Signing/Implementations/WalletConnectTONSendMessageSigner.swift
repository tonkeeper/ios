import Foundation

struct WalletConnectTONSendMessageSigner: WalletConnectRequestPayloadSigner {
    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .tonSendMessage(message) = request.payload else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires TON send message payload")
        }

        try context.validateAddress(message.from, chain: .ton)
        throw .notImplemented(reason: "ChainKit TON sendMessage is not implemented")
    }
}

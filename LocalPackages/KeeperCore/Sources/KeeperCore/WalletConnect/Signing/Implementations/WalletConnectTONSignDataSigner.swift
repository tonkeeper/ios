import Foundation

struct WalletConnectTONSignDataSigner: WalletConnectRequestPayloadSigner {
    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .tonSignData(signData) = request.payload else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires TON sign data payload")
        }

        try context.validateAddress(signData.address, chain: .ton)
        throw .notImplemented(reason: "ChainKit TON signData is not implemented")
    }
}

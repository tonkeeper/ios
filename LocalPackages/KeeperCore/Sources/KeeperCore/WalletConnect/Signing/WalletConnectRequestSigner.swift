import Foundation

protocol WalletConnectRequestPayloadSigner {
    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue
}

struct WalletConnectRequestSigner {
    private let signers: [WalletConnectMethod: WalletConnectRequestPayloadSigner]

    init() {
        signers = [
            .personalSign: WalletConnectPersonalSignSigner(),
            .ethSignTypedDataV4: WalletConnectEthSignTypedDataV4Signer(),
            .ethSignTransaction: WalletConnectEthSignTransactionSigner(),
            .ethSendTransaction: WalletConnectEthSendTransactionSigner(),
            .tronSignMessage: WalletConnectTronSignMessageSigner(),
            .tronSignTransaction: WalletConnectTronSignTransactionSigner(),
            .tonSendMessage: WalletConnectTONSendMessageSigner(),
            .tonSignData: WalletConnectTONSignDataSigner(),
        ]
    }

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard let signer = signers[request.method] else {
            throw .invalidPayload(reason: "\(request.method.rawValue) is handled without signing")
        }
        return try await signer.sign(request: request, context: context)
    }
}

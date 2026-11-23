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
            .solanaSignMessage: WalletConnectSolanaSignMessageSigner(),
            .solanaSignTransaction: WalletConnectSolanaSignTransactionSigner(),
            .solanaSignAndSendTransaction: WalletConnectSolanaSignTransactionSigner(),
            .solanaSignAllTransactions: WalletConnectSolanaSignAllTransactionsSigner(),
        ]
    }

    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard let signer = signers[request.method] else {
            throw .invalidPayload(reason: "\(request.method.rawValue) is handled without signing")
        }
        try await context.checkRequestIsPending()
        let response: WalletConnectResponseValue
        do throws(WalletConnectSigningError) {
            if case let .device(device) = context.signer {
                response = try await WalletConnectDeviceRequestSigner().sign(request: request, context: context, device: device)
            } else {
                response = try await signer.sign(request: request, context: context)
            }
        } catch {
            try await context.checkRequestIsPending()
            throw error
        }
        try await context.checkRequestIsPending()
        return response
    }
}

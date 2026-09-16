import ChainKit
import Foundation

struct WalletConnectTronSignMessageSigner: WalletConnectRequestPayloadSigner {
    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .signMessage(message) = request.payload,
              case .tron = message.kind
        else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires tron sign message payload")
        }

        try context.validateAddress(message.address, chain: request.chain)
        let privateKeyData = try await context.cryptoWallet()
            .getPrivateKey(chain: request.chain.multichainChain.asChainKitChain)
            .data()
            .asData

        do {
            let signature = try WalletConnectTronMessageSigner.sign(
                message: message.message,
                privateKeyData: privateKeyData
            )
            return .object(["signature": signature])
        } catch {
            throw .failedToSign(reason: "failed to sign tron message: \(error.logDescription)")
        }
    }
}

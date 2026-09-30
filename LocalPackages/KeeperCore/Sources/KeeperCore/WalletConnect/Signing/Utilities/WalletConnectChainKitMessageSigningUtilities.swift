import ChainKit
import Foundation

enum WalletConnectEVMMessageKind {
    case personal
    case typedDataV4
}

struct WalletConnectChainKitMessageSigningUtilities {
    func sign(
        client: CryptoKitClient,
        chain: WalletConnectChain,
        cryptoWallet: CryptoWallet,
        message: String,
        kind: WalletConnectEVMMessageKind
    ) async throws(WalletConnectSigningError) -> String {
        let chainKitChain = chain.multichainChain.asChainKitChain
        guard let messageSigner = client.blockchain
            .getMediator(network: chainKitChain.network.type)
            .sign
            .message
        else {
            throw .failedToSign(reason: "chainkit message signer is not available for \(chain.caip2)")
        }

        let messageType: ChainKit.MessageType = switch kind {
        case .personal: .legacy
        case .typedDataV4: .typedmessage
        }
        let privateKey = cryptoWallet.getPrivateKey(chain: chainKitChain)
        return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<String, WalletConnectSigningError>, Never>) in
            messageSigner.sign(
                chain: chainKitChain,
                privateKey: privateKey,
                message: message,
                messageType: messageType
            ) { result, error in
                if let error {
                    continuation.resume(
                        returning: .failure(
                            .failedToSign(reason: "chainkit failed to sign message: \(error.logDescription)")
                        )
                    )
                    return
                }
                guard let value = result?.getOrNull() else {
                    let reason = result.flatMap(\.error).map { "\($0)" } ?? "unknown"
                    continuation.resume(
                        returning: .failure(
                            .failedToSign(reason: "chainkit failed to sign message: \(reason)")
                        )
                    )
                    return
                }
                continuation.resume(returning: .success(value as String))
            }
        }.get()
    }
}

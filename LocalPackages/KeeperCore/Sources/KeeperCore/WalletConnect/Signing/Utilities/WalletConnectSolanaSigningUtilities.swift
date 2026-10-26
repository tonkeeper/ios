import ChainKit
import Foundation

struct WalletConnectSolanaSignedTransaction: Equatable {
    var signature: String
    var transaction: String
}

struct WalletConnectSolanaSigningUtilities {
    private let messageSigning = WalletConnectChainKitMessageSigningUtilities()

    func signMessage(
        _ message: String,
        client: CryptoKitClient,
        cryptoWallet: CryptoWallet
    ) async throws(WalletConnectSigningError) -> String {
        let response = try await signedFields(
            message,
            messageType: .default_,
            client: client,
            cryptoWallet: cryptoWallet
        )
        guard let signature = response["signature"] else {
            throw .failedToSign(reason: "chainkit solana signature is missing")
        }
        return signature
    }

    func signTransaction(
        _ transaction: String,
        client: CryptoKitClient,
        cryptoWallet: CryptoWallet
    ) async throws(WalletConnectSigningError) -> WalletConnectSolanaSignedTransaction {
        let response = try await signedFields(
            transaction,
            messageType: .transaction,
            client: client,
            cryptoWallet: cryptoWallet
        )
        guard let signature = response["signature"],
              let signedTransaction = response["transaction"]
        else {
            throw .failedToSign(reason: "chainkit solana signed transaction is incomplete")
        }
        return WalletConnectSolanaSignedTransaction(
            signature: signature,
            transaction: signedTransaction
        )
    }

    func send(
        _ transaction: String,
        client: CryptoKitClient,
        account: ChainKit.Account
    ) async throws(WalletConnectSigningError) -> String {
        let mediator = client.blockchain.getMediator(
            network: MultichainChain.sol.asChainKitChain.network.type
        )
        return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<String, WalletConnectSigningError>, Never>) in
            mediator.transaction.sendRawTransaction(
                account: account,
                transaction: transaction
            ) { result, error in
                if let error {
                    continuation.resume(
                        returning: .failure(
                            .failedToSend(reason: "chainkit failed to send transaction: \(error.logDescription)")
                        )
                    )
                    return
                }
                guard let signature = result?.getOrNull() else {
                    let reason = result.flatMap(\.error).map { "\($0)" } ?? "unknown"
                    continuation.resume(
                        returning: .failure(
                            .failedToSend(reason: "chainkit failed to send transaction: \(reason)")
                        )
                    )
                    return
                }
                continuation.resume(returning: .success(signature as String))
            }
        }.get()
    }
}

private extension WalletConnectSolanaSigningUtilities {
    func signedFields(
        _ message: String,
        messageType: ChainKit.MessageType,
        client: CryptoKitClient,
        cryptoWallet: CryptoWallet
    ) async throws(WalletConnectSigningError) -> [String: String] {
        let json = try await messageSigning.sign(
            client: client,
            chain: .sol,
            cryptoWallet: cryptoWallet,
            message: message,
            messageType: messageType
        )
        do {
            return try JSONDecoder().decode([String: String].self, from: Data(json.utf8))
        } catch {
            throw .failedToSign(reason: "chainkit solana signature is not a JSON object: \(error.logDescription)")
        }
    }
}

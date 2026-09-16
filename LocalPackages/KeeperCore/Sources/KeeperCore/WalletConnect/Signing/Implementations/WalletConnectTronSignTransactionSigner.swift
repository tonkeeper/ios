import ChainKit
import Foundation

struct WalletConnectTronSignTransactionSigner: WalletConnectRequestPayloadSigner {
    func sign(
        request: WalletConnectSessionRequest,
        context: WalletConnectSigningContext
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case let .tronTransaction(transaction) = request.payload else {
            throw .invalidPayload(reason: "\(request.method.rawValue) requires tron transaction payload")
        }
        guard let rawDataHex = transaction.rawDataHex,
              let rawData = Data(walletConnectHex: rawDataHex)
        else {
            throw .invalidTransaction(reason: "tron transaction raw_data_hex is missing or invalid")
        }

        try context.validateAddress(transaction.address, chain: .tron)
        let privateKeyData = try await context.cryptoWallet()
            .getPrivateKey(chain: MultichainChain.tron.asChainKitChain)
            .data()
            .asData

        let signedTransaction = try WalletConnectTronTransactionSigner.sign(
            rawData: rawData,
            privateKeyData: privateKeyData
        )
        let response = try WalletConnectTronTransactionSigner.signedTransactionJSON(
            transactionJSON: transaction.transactionJSON,
            signedTransaction: signedTransaction
        )
        return .json(response)
    }
}

@preconcurrency import AnyCodable
import CryptoKit
import CryptoSwift
import Foundation
import TronSwift

enum WalletConnectTronTransactionSigner {
    struct SignedTransaction: Equatable {
        let txID: String
        let signature: String
    }

    static func sign(
        rawData: Data,
        privateKeyData: Data
    ) throws(WalletConnectSigningError) -> SignedTransaction {
        guard !rawData.isEmpty else {
            throw .invalidTransaction(reason: "tron transaction raw_data_hex is missing or invalid")
        }

        let txID = Data(SHA256.hash(data: rawData))
        do {
            let privateKey = TronSwift.PrivateKey(
                data: privateKeyData,
                chainCode: Data()
            )
            let signature = try Signer().sign(hash: txID, privateKey: privateKey)
            return SignedTransaction(
                txID: txID.hexString(),
                signature: signature.hexString()
            )
        } catch {
            throw .failedToSign(
                reason: "failed to sign tron transaction: \(error.logDescription)"
            )
        }
    }

    static func txID(rawDataHex: String) throws(WalletConnectSigningError) -> String {
        guard let rawData = Data(walletConnectHex: rawDataHex),
              !rawData.isEmpty
        else {
            throw .invalidTransaction(reason: "tron transaction raw_data_hex is missing or invalid")
        }
        return Data(SHA256.hash(data: rawData)).hexString()
    }

    static func signedTransactionJSON(
        transactionJSON: AnyCodable,
        signedTransaction: SignedTransaction
    ) throws(WalletConnectSigningError) -> AnyCodable {
        guard var object = transactionJSON.walletConnectObjectValue else {
            throw .invalidTransaction(reason: "tron transaction is not a JSON object")
        }
        object["txID"] = signedTransaction.txID
        object["signature"] = [signedTransaction.signature]
        return AnyCodable(object)
    }
}

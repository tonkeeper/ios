@preconcurrency import AnyCodable
import CryptoKit
import CryptoSwift
import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import XCTest

final class WalletConnectTronMessageSignerTests: XCTestCase {
    func testSignMessageMatchesTronWebV2Vector() throws {
        let privateKey = try XCTUnwrap(Data(strictHex: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"))

        let signature = try WalletConnectTronMessageSigner.sign(
            message: "hello",
            privateKeyData: privateKey
        )

        XCTAssertEqual(
            signature,
            "0xadfca21d9b05d5fe21698907a26f17039b817dc5655f9139c16e1ca597529cf33a24dcce9f971b065531630ea3454291e00376241c31d6218ddc7251402a15b41c"
        )
    }

    func testSignTransactionReturnsComputedTxID() throws {
        let rawData = try XCTUnwrap(Data(strictHex: "0a02"))
        let privateKey = try XCTUnwrap(Data(strictHex: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"))

        let signedTransaction = try WalletConnectTronTransactionSigner.sign(
            rawData: rawData,
            privateKeyData: privateKey
        )

        XCTAssertEqual(signedTransaction.txID, Data(SHA256.hash(data: rawData)).hexString())
        XCTAssertEqual(signedTransaction.signature.count, 130)
    }

    func testSignedTransactionJSONOverwritesDappTxID() throws {
        let response = try WalletConnectTronTransactionSigner.signedTransactionJSON(
            transactionJSON: AnyCodable([
                "raw_data_hex": "0a02",
                "txID": "deadbeef",
            ] as [String: String]),
            signedTransaction: WalletConnectTronTransactionSigner.SignedTransaction(
                txID: "computed",
                signature: "signature"
            )
        )

        let data = try JSONEncoder().encode(response)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["raw_data_hex"] as? String, "0a02")
        XCTAssertEqual(object["txID"] as? String, "computed")
        XCTAssertEqual(object["signature"] as? [String], ["signature"])
    }

    func testSignTransactionRejectsEmptyRawData() throws {
        let privateKey = try XCTUnwrap(Data(strictHex: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"))

        XCTAssertThrowsError(
            try WalletConnectTronTransactionSigner.sign(
                rawData: Data(),
                privateKeyData: privateKey
            )
        ) { error in
            XCTAssertEqual(
                error as? WalletConnectSigningError,
                .invalidTransaction(reason: "tron transaction raw_data_hex is missing or invalid")
            )
        }
    }
}

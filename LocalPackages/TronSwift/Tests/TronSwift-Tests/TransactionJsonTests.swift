import Foundation
@testable import TronSwift
@testable import TronSwiftAPI
import XCTest

/// The battery relay broadcasts from `toJson()` while the signature covers `raw_data_hex`, so what
/// this emits has to stay the node's own object rather than a reconstruction of the fields this
/// codebase happens to parse.
final class TransactionJsonTests: XCTestCase {
    func test_toJson_keepsARawDataFieldThisTypeDoesNotParse() throws {
        let transaction = try XCTUnwrap(Transaction(json: Self.response(rawDataExtras: ["data": "c0ffee"])))

        let rawData = try XCTUnwrap(transaction.toJson()["raw_data"] as? [String: Any])
        XCTAssertEqual(rawData["data"] as? String, "c0ffee")
    }

    func test_toJson_omitsAFieldTheNodeDidNotSend() throws {
        let transaction = try XCTUnwrap(Transaction(json: Self.response()))

        let rawData = try XCTUnwrap(transaction.toJson()["raw_data"] as? [String: Any])
        XCTAssertNil(rawData.index(forKey: "fee_limit"))
    }

    func test_toJson_isSerializableForTheRelay() throws {
        let transaction = try XCTUnwrap(Transaction(json: Self.response()))

        XCTAssertTrue(JSONSerialization.isValidJSONObject(transaction.toJson()))
    }

    func test_toJson_carriesTheExtendedExpirationAndNothingElse() throws {
        let transaction = try XCTUnwrap(Transaction(json: Self.response(rawDataExtras: ["data": "c0ffee"])))

        let extended = try transaction.extendingExpiration(byMilliseconds: 600_000)

        let rawData = try XCTUnwrap(extended.toJson()["raw_data"] as? [String: Any])
        XCTAssertEqual(rawData["expiration"] as? Int64, Self.expiration + 600_000)
        XCTAssertEqual(rawData["data"] as? String, "c0ffee")
        XCTAssertEqual(rawData["ref_block_bytes"] as? String, "f96c")
    }

    /// `visible` and the address encoding inside `contract` are one decision: the node reads base58
    /// addresses only when the flag is set, and rejects the transfer with "No contract!" otherwise.
    /// `wallet/createtransaction` is asked in base58 and echoes the flag; `wallet/triggersmartcontract`
    /// is asked in hex and sends no flag.
    func test_nativeTransfer_keepsTheVisibleFlagItWasBuiltWith() throws {
        var json = Self.response()
        json["visible"] = true

        let transaction = try TronApi.nativeTransferTransaction(from: json)

        XCTAssertEqual(transaction.toJson()["visible"] as? Bool, true)
    }

    func test_transferTransaction_staysWithoutAVisibleFlag() throws {
        let transaction = try TronApi.transferTransaction(from: ["transaction": Self.response()])

        XCTAssertNil(transaction.toJson().index(forKey: "visible"))
    }

    private static let expiration: Int64 = 1_786_060_362_000

    private static func response(rawDataExtras: [String: Any] = [:]) -> [String: Any] {
        var rawData: [String: Any] = [
            "ref_block_bytes": "f96c",
            "ref_block_hash": "f0006781f475a642",
            "expiration": expiration,
            "timestamp": Int64(1_786_059_703_419),
            "contract": [["type": "TransferContract"]],
        ]
        rawData.merge(rawDataExtras) { _, new in new }

        return [
            "txID": "2f2df28fa163a3bd1a03ae5b77977d3528ad66e6ce4968310935e97a1fc887d4",
            "raw_data_hex": "0a02f96c2208f0006781f475a6424090a2f9cbfd3370fb88d1cbfd33",
            "raw_data": rawData,
        ]
    }
}

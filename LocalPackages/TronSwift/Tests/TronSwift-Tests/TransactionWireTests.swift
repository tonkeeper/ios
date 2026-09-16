import Foundation
import TKCryptoKit
@testable import TronSwift
import XCTest

final class TransactionWireTests: XCTestCase {
    /// `raw_data_hex`, `expiration` and `txID` of the USDT transfer from the TK-2909 trace.
    private static let traceRawDataHex =
        "0a02f96c2208f0006781f475a6424090a2f9cbfd335aae01081f12a9010a31747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e54726967676572536d617274436f6e747261637412740a15416bda46f57114c4c3a2617c2ad3b1722d81360df4121541a614f803b6fd780986a42c78ec9c7f77e6ded13c2244a9059cbb0000000000000000000000006bda46f57114c4c3a2617c2ad3b1722d81360df400000000000000000000000000000000000000000000000000000000002dc6c070fb88d1cbfd33900180a3c347"
    private static let traceExpiration: Int64 = 1_786_060_362_000
    private static let traceTxID = "6dc40f865e84d01ffeb4a8648614073e7e5d9bf21dd3748f23ed9ddceb861677"

    // MARK: - Happy path

    func test_extendingByZero_reproducesNodeBytesAndTxID() throws {
        let extended = try Self.traceTransaction().extendingExpiration(byMilliseconds: 0)

        XCTAssertEqual(extended.rawDataHex, Self.traceRawDataHex)
        XCTAssertEqual(extended.txID, Self.traceTxID)
        XCTAssertEqual(extended.rawData.expiration, Self.traceExpiration)
    }

    func test_extendingExpiration_touchesNothingButTheExpirationRecord() throws {
        let original = try ProtobufWire.decodeHex(Self.traceRawDataHex)
        let record = try XCTUnwrap(Self.expirationField(in: original))
        let head = Array(original[..<record.range.lowerBound])
        let tail = Array(original[record.range.upperBound...])

        let extended = try Self.traceTransaction().extendingExpiration(byMilliseconds: 600_000)
        let patched = try ProtobufWire.decodeHex(extended.rawDataHex)

        XCTAssertEqual(Array(patched.prefix(head.count)), head)
        XCTAssertEqual(Array(patched.suffix(tail.count)), tail)
        XCTAssertEqual(try Self.expirationField(in: patched)?.varint, UInt64(Self.traceExpiration + 600_000))
        XCTAssertEqual(extended.rawData.expiration, Self.traceExpiration + 600_000)
        XCTAssertEqual(extended.txID, SHA256.hash(data: Data(patched)).hexString())
        XCTAssertNil(extended.signature)
    }

    func test_extendingExpiration_keepsVisibilityAndContract() throws {
        let transaction = Self.transaction(
            rawDataHex: Self.traceRawDataHex,
            expiration: Self.traceExpiration,
            isVisible: true,
            contract: [["type": "TriggerSmartContract"]]
        )

        let extended = try transaction.extendingExpiration(byMilliseconds: 600_000)

        XCTAssertEqual(extended.isVisible, true)
        XCTAssertEqual((extended.rawData.contract as? [[String: String]])?.first?["type"], "TriggerSmartContract")
    }

    func test_extendingExpiration_growsVarintAcrossSevenBitBoundary() throws {
        let transaction = Self.synthetic(expirationRecord: "407f", expiration: 127)

        let extended = try transaction.extendingExpiration(byMilliseconds: 1)

        XCTAssertEqual(extended.rawDataHex, Self.syntheticHex(expirationRecord: "408001"))
        XCTAssertEqual(extended.rawData.expiration, 128)
    }

    func test_extendingExpiration_shrinksVarintAcrossSevenBitBoundary() throws {
        let transaction = Self.synthetic(expirationRecord: "408001", expiration: 128)

        let extended = try transaction.extendingExpiration(byMilliseconds: -1)

        XCTAssertEqual(extended.rawDataHex, Self.syntheticHex(expirationRecord: "407f"))
        XCTAssertEqual(extended.rawData.expiration, 127)
    }

    func test_extendingExpiration_appendsMissingRecord() throws {
        let transaction = Self.synthetic(expirationRecord: "", expiration: 0)

        let extended = try transaction.extendingExpiration(byMilliseconds: 600_000)

        // 600 000 as a varint: c0 cf 24.
        XCTAssertEqual(extended.rawDataHex, Self.syntheticHex(expirationRecord: "") + "40c0cf24")
        XCTAssertEqual(extended.rawData.expiration, 600_000)
    }

    func test_signingDigest_matchesNodeTxID() throws {
        XCTAssertEqual(try Self.traceTransaction().signingDigest().hexString(), Self.traceTxID)
    }

    // MARK: - Rejections

    func test_extendingExpiration_rejectsSignedTransaction() {
        let transaction = Self.transaction(
            rawDataHex: Self.traceRawDataHex,
            expiration: Self.traceExpiration,
            signature: String(repeating: "ab", count: 65)
        )

        XCTAssertThrowsError(try transaction.extendingExpiration(byMilliseconds: 600_000)) {
            XCTAssertEqual($0 as? Transaction.WireFormatError, .alreadySigned)
        }
    }

    func test_extendingExpiration_rejectsMalformedRawData() {
        let cases: [(name: String, hex: String, expiration: Int64)] = [
            ("odd length", "0a02f96c4090a2f9cbfd337", Self.traceExpiration),
            ("non hex digit", "0a02f96c40zz", Self.traceExpiration),
            ("truncated varint", "0a02f96c4090", Self.traceExpiration),
            ("varint over ten bytes", "40" + String(repeating: "ff", count: 10) + "01", 0),
            ("ten byte varint with unusable high payload", "40" + String(repeating: "ff", count: 9) + "02", 0),
            ("length delimited past the end", "0a10f96c", 0),
            ("truncated fixed64", "090011223344", 0),
            ("truncated fixed32", "0d001122", 0),
            ("reserved wire type", "0b01", 0),
            ("zero field number", "0001", 0),
            ("duplicate expiration record", "40014002", 1),
            ("expiration disagrees with json", "4001", 2),
            ("expiration is not a varint", "4201f0", 0),
        ]

        for testCase in cases {
            let transaction = Self.transaction(rawDataHex: testCase.hex, expiration: testCase.expiration)
            XCTAssertThrowsError(
                try transaction.extendingExpiration(byMilliseconds: 600_000),
                testCase.name
            ) {
                XCTAssertEqual($0 as? Transaction.WireFormatError, .malformedRawData, testCase.name)
            }
        }
    }

    func test_extendingExpiration_rejectsOverflow() {
        // Int64.max as a varint: nine groups of seven set bits.
        let transaction = Self.transaction(
            rawDataHex: "40" + String(repeating: "ff", count: 8) + "7f",
            expiration: .max
        )

        XCTAssertThrowsError(try transaction.extendingExpiration(byMilliseconds: 1)) {
            XCTAssertEqual($0 as? Transaction.WireFormatError, .expirationOverflow)
        }
    }

    func test_signingDigest_rejectsMalformedRawData() {
        let transaction = Self.transaction(rawDataHex: "0a02f96c4090a2f9cbfd337", expiration: Self.traceExpiration)

        XCTAssertThrowsError(try transaction.signingDigest()) {
            XCTAssertEqual($0 as? Transaction.WireFormatError, .malformedRawData)
        }
    }

    // MARK: - Signed envelope

    func test_signedProtobufHex_wrapsRawDataAndSignature() throws {
        let signature = String(repeating: "ab", count: 65)
        let transaction = Self.transaction(
            rawDataHex: Self.traceRawDataHex,
            expiration: Self.traceExpiration,
            signature: signature
        )

        // 211 bytes of raw_data are length-prefixed as d3 01, 65 bytes of signature as 41.
        XCTAssertEqual(
            try transaction.signedProtobufHex(),
            "0ad301" + Self.traceRawDataHex + "1241" + signature
        )
    }

    func test_signedProtobufHex_encodesLengthAcrossVarintBoundaries() throws {
        let signature = String(repeating: "ab", count: 65)
        let expected: [(byteCount: Int, lengthPrefix: String)] = [
            (127, "7f"),
            (128, "8001"),
            (16384, "808001"),
        ]

        for testCase in expected {
            let rawDataHex = String(repeating: "00", count: testCase.byteCount)
            let transaction = Self.transaction(rawDataHex: rawDataHex, expiration: 0, signature: signature)

            XCTAssertEqual(
                try transaction.signedProtobufHex(),
                "0a" + testCase.lengthPrefix + rawDataHex + "1241" + signature,
                "\(testCase.byteCount) bytes"
            )
        }
    }

    func test_signedProtobufHex_rejectsUnusableSignature() {
        let cases: [(name: String, signature: String?)] = [
            ("missing", nil),
            ("empty", ""),
            ("odd length", String(repeating: "ab", count: 64) + "c"),
            ("non hex digit", String(repeating: "ab", count: 64) + "zz"),
        ]

        for testCase in cases {
            let transaction = Self.transaction(
                rawDataHex: Self.traceRawDataHex,
                expiration: Self.traceExpiration,
                signature: testCase.signature
            )
            XCTAssertThrowsError(try transaction.signedProtobufHex(), testCase.name) {
                let expected: Transaction.WireFormatError = testCase.signature == nil
                    ? .missingSignature
                    : .malformedSignature
                XCTAssertEqual($0 as? Transaction.WireFormatError, expected, testCase.name)
            }
        }
    }

    func test_signedProtobufHex_rejectsMalformedRawData() {
        let transaction = Self.transaction(
            rawDataHex: "0a02f96c4090a2f9cbfd337",
            expiration: Self.traceExpiration,
            signature: String(repeating: "ab", count: 65)
        )

        XCTAssertThrowsError(try transaction.signedProtobufHex()) {
            XCTAssertEqual($0 as? Transaction.WireFormatError, .malformedRawData)
        }
    }

    // MARK: - Fixtures

    private static func expirationField(in bytes: [UInt8]) throws -> ProtobufWire.Field? {
        try ProtobufWire.scanFields(bytes).first { $0.number == 8 }
    }

    /// A minimal `raw_data`: `ref_block_bytes`, the expiration record under test, `timestamp`.
    private static func syntheticHex(expirationRecord: String) -> String {
        "0a02f96c" + expirationRecord + "70fb88d1cbfd33"
    }

    private static func synthetic(expirationRecord: String, expiration: Int64) -> Transaction {
        transaction(rawDataHex: syntheticHex(expirationRecord: expirationRecord), expiration: expiration)
    }

    private static func traceTransaction() -> Transaction {
        transaction(rawDataHex: traceRawDataHex, expiration: traceExpiration)
    }

    private static func transaction(
        rawDataHex: String,
        expiration: Int64,
        signature: String? = nil,
        isVisible: Bool? = nil,
        contract: Any? = nil
    ) -> Transaction {
        Transaction(
            isVisible: isVisible,
            txID: traceTxID,
            rawDataHex: rawDataHex,
            rawData: Transaction.RawData(
                json: [
                    "ref_block_bytes": "f96c",
                    "ref_block_hash": "f0006781f475a642",
                    "expiration": expiration,
                    "fee_limit": 150_000_000,
                    "timestamp": 1_786_059_703_419,
                    "contract": contract as Any,
                ],
                expiration: expiration
            ),
            signature: signature
        )
    }
}

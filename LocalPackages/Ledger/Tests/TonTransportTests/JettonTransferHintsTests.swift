import BigInt
import TonSwift
@testable import TonTransport
import XCTest

final class JettonTransferHintsTests: XCTestCase {
    /// header + seqno + timeout + coins(0) + address + bounceable + sendMode + no stateInit
    /// + hasPayload + depth + hash, everything before the hint section.
    private let hintsOffset = 1 + 4 + 4 + 1 + 33 + 1 + 1 + 1 + 1 + 2 + 32
    /// 1_000_000 as var-uint: 3-byte length prefix then big-endian value.
    private let coinsBytes: [UInt8] = [0x03, 0x0F, 0x42, 0x40]

    func testFlagsByteIsZeroWithoutQueryIdAndKnownJetton() throws {
        let bytes = try hintBytes(TransactionFixtures.jettonTransfer())
        XCTAssertEqual(bytes[0], 0x00)
        XCTAssertEqual(Array(bytes[1 ..< 5]), coinsBytes, "var-uint coins follow the flags directly")
    }

    func testQueryIdSetsFlagBitAndIsWrittenBeforeCoins() throws {
        let bytes = try hintBytes(TransactionFixtures.jettonTransfer(queryId: 0x0102_0304_0506_0708))
        XCTAssertEqual(Array(bytes[0 ..< 9]), [0x01, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        XCTAssertEqual(Array(bytes[9 ..< 13]), coinsBytes)
    }

    func testKnownJettonSetsFlagBitAndWritesIdAndWorkchain() throws {
        let known = KnownJetton(jettonId: 10, workchain: 0)
        let bytes = try hintBytes(TransactionFixtures.jettonTransfer(knownJetton: known))
        XCTAssertEqual(Array(bytes[0 ..< 4]), [0x02, 0x00, 0x0A, 0x00])
        XCTAssertEqual(Array(bytes[4 ..< 8]), coinsBytes)
    }

    func testKnownJettonFollowsQueryId() throws {
        let known = KnownJetton(jettonId: 0x0102, workchain: -1)
        let bytes = try hintBytes(TransactionFixtures.jettonTransfer(queryId: 42, knownJetton: known))
        XCTAssertEqual(Array(bytes[0 ..< 12]), [0x03, 0, 0, 0, 0, 0, 0, 0, 42, 0x01, 0x02, 0xFF])
        XCTAssertEqual(Array(bytes[12 ..< 16]), coinsBytes)
    }

    func testKnownJettonOnlyExtendsHintsAndKeepsRestIdentical() throws {
        let plain = try TonTransport.buildTransfer(transaction: TransactionFixtures.jettonTransfer(queryId: 1))
        let known = try TonTransport.buildTransfer(
            transaction: TransactionFixtures.jettonTransfer(queryId: 1, knownJetton: KnownJetton(jettonId: 0, workchain: 0))
        )

        XCTAssertEqual(known.package.count, plain.package.count + 3)
        XCTAssertEqual(known.package.prefix(hintsOffset), plain.package.prefix(hintsOffset), "cell hash must not change")
        XCTAssertEqual(try known.signingMessage.endCell().hash(), try plain.signingMessage.endCell().hash())

        let plainBytes = try hintBytes(from: plain.package)
        let knownBytes = try hintBytes(from: known.package)
        XCTAssertEqual(knownBytes.dropFirst(1 + 8 + 3), plainBytes.dropFirst(1 + 8))
    }

    private func hintBytes(_ transaction: Transaction) throws -> [UInt8] {
        try hintBytes(from: TonTransport.buildTransfer(transaction: transaction).package)
    }

    private func hintBytes(from package: Data) throws -> [UInt8] {
        let hints = [UInt8](package.dropFirst(hintsOffset))
        XCTAssertEqual(Array(hints[0 ..< 5]), [0x01, 0x00, 0x00, 0x00, 0x01], "jetton-transfer hint kind")
        let length = Int(hints[5]) << 8 | Int(hints[6])
        let bytes = Array(hints[7...])
        XCTAssertEqual(bytes.count, length)
        return bytes
    }
}

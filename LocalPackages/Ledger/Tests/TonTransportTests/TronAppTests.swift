import CryptoKit
@testable import LedgerKit
import XCTest

final class TronAppTests: XCTestCase {
    private let path = TronApp.path(account: 0)

    func testPathFollowsLedgerLive() {
        XCTAssertEqual(hex(path), "058000002c800000c3800000000000000000000000")
        XCTAssertEqual(hex(TronApp.path(account: 2)), "058000002c800000c3800000020000000000000000")
    }

    func testSilentAddressRequest() async throws {
        let publicKey = Data([0x04]) + Data(repeating: 0xAB, count: 64)
        let address = Data("TJmmqjb1DK9TTZbQXzRQ2AuA94z4gKAPFh".utf8)
        let device = FakeDevice(replies: [Data([65]) + publicKey + Data([UInt8(address.count)]) + address + ok])

        let account = try await device.link.tronAccount(path: path)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e002000015" + hex(path)])
        XCTAssertEqual(account, TronApp.Account(publicKey: publicKey, address: "TJmmqjb1DK9TTZbQXzRQ2AuA94z4gKAPFh"))
    }

    func testAShortTransactionGoesInOnePayload() async throws {
        let rawData = field(1, length: 10) + field(2, length: 20)
        let device = FakeDevice(replies: [signature + ok])

        let signed = try await device.link.signTronTransaction(rawData, path: path)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e0041000" + String(format: "%02x", path.count + rawData.count) + hex(path + rawData)])
        XCTAssertEqual(signed, signature)
    }

    func testPayloadsEndOnFieldBoundaries() throws {
        let first = field(1, length: 200)
        let second = field(2, length: 100)

        let chunks = try XCTUnwrap(TronApp.signChunks(path: path, rawData: first + second))

        XCTAssertEqual(chunks, [path + first, second])
        XCTAssertEqual((0 ..< 3).map { TronApp.signP1(index: $0, count: 3) }, [0x00, 0x80, 0x90])
    }

    func testAFieldTooLongForAPayloadIsSignedByHash() async throws {
        let rawData = field(1, length: 300)
        let device = FakeDevice(replies: [signature + ok])

        _ = try await device.link.signTronTransaction(rawData, path: path)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e005000035" + hex(path) + hex(Data(SHA256.hash(data: rawData)))])
    }

    func testMalformedTransactionIsRefused() {
        XCTAssertThrowsError(try TronApp.signChunks(path: path, rawData: Data([0x0A, 0x05, 0x01])))
    }

    func testSettingsNamedByTheirStatusWords() {
        XCTAssertEqual(TronApp.Setting(LedgerStatusError(statusWord: 0x6A8B)), .transactionsData)
        XCTAssertEqual(TronApp.Setting(LedgerStatusError(statusWord: 0x6A8C)), .signByHash)
        XCTAssertEqual(TronApp.Setting(LedgerStatusError(statusWord: 0x6A8D)), .customContracts)
        XCTAssertNil(TronApp.Setting(LedgerStatusError(statusWord: 0x6985)))
    }

    func testPersonalMessageCarriesItsLengthAfterThePath() async throws {
        let message = Data("hello".utf8)
        let device = FakeDevice(replies: [signature + ok])

        let signed = try await device.link.signTronPersonalMessage(message, path: path)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e00800001e" + hex(path) + "00000005" + hex(message)])
        XCTAssertEqual(signed, Data(repeating: 0x11, count: 64) + Data([28]))
    }

    func testLongPersonalMessageFillsThePayloadAfterThePath() {
        let chunks = TronApp.messageChunks(path: path, message: Data(repeating: 0x61, count: 400))

        XCTAssertEqual(chunks.map(\.count), [250, 175])
        XCTAssertEqual(chunks[0].prefix(path.count), path)
    }

    /// A length-delimited protobuf field whose value is `length` bytes.
    private func field(_ number: UInt8, length: Int) -> Data {
        let size = length < 0x80 ? Data([UInt8(length)]) : Data([UInt8(length & 0x7F) | 0x80, UInt8(length >> 7)])
        return Data([number << 3 | 2]) + size + Data(repeating: 0xEE, count: length)
    }
}

private let ok = Data([0x90, 0x00])
private let signature = Data(repeating: 0x11, count: 64) + Data([0x01])

private func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

@testable import LedgerKit
import XCTest

final class SolanaAppTests: XCTestCase {
    private let path = SolanaApp.path(account: 0)

    func testPathFollowsLedgerLive() {
        XCTAssertEqual(hex(path), "048000002c800001f58000000080000000")
        XCTAssertEqual(hex(SolanaApp.path(account: 4)), "048000002c800001f58000000480000000")
    }

    func testSilentKeyRequest() async throws {
        let key = Data(repeating: 0x5A, count: 32)
        let device = FakeDevice(replies: [key + ok])

        let publicKey = try await device.link.solanaPublicKey(path: path)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e005000011" + hex(path)])
        XCTAssertEqual(publicKey, key)
    }

    func testAShortMessageGoesInOnePayload() async throws {
        let message = Data(repeating: 0xAB, count: 100)
        let device = FakeDevice(replies: [signature + ok])

        let signed = try await device.link.signSolanaMessage(message, path: path)

        let sent = await device.sent
        XCTAssertEqual(sent, ["e0060100" + String(format: "%02x", 1 + path.count + message.count) + "01" + hex(path) + hex(message)])
        XCTAssertEqual(signed, signature)
    }

    func testALongMessageExtendsTheFirstPayload() async throws {
        let message = Data(repeating: 0xAB, count: 600)
        let device = FakeDevice(replies: [ok, ok, signature + ok])

        _ = try await device.link.signSolanaMessage(message, path: path)

        let sent = await device.sent
        XCTAssertEqual(sent.map { String($0.prefix(10)) }, ["e0060102ff", "e0060103ff", "e00601016c"])
    }

    func testBlindSigningIsNamedByItsStatusWord() {
        XCTAssertTrue(SolanaApp.requiresBlindSigning(LedgerStatusError(statusWord: 0x6808)))
        XCTAssertFalse(SolanaApp.requiresBlindSigning(LedgerStatusError(statusWord: 0x6985)))
    }
}

private let ok = Data([0x90, 0x00])
private let signature = Data(repeating: 0x33, count: 64)

private func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}

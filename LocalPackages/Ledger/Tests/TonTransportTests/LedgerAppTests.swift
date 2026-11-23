@testable import LedgerKit
import XCTest

final class LedgerAppTests: XCTestCase {
    func testOpenAppReturnsItsVersion() async throws {
        let device = FakeDevice(replies: [appInfo("Ethereum", "1.12.0")])

        let version = try await device.link.open(.ethereum)

        XCTAssertEqual(version, "1.12.0")
        let sent = await device.sent
        XCTAssertEqual(sent, ["b001000000"])
    }

    func testDashboardOpensTheApp() async throws {
        let device = FakeDevice(replies: [appInfo("BOLOS", "1.0.1"), ok])

        let version = try await device.link.open(.ethereum)

        XCTAssertNil(version)
        let sent = await device.sent
        XCTAssertEqual(sent, ["b001000000", "e0d8000008457468657265756d"])
    }

    func testAnotherAppIsQuitFirst() async throws {
        let device = FakeDevice(replies: [appInfo("TON", "2.7.0"), ok])

        let version = try await device.link.open(.ethereum)

        XCTAssertNil(version)
        let sent = await device.sent
        XCTAssertEqual(sent, ["b001000000", "b0a7000000"])
    }

    func testLockedOrBusyLedgerIsPolledAgain() async throws {
        for statusWord: [UInt8] in [[0x55, 0x15], [0x69, 0x82], [0x53, 0x03], [0x6B, 0x0C], [0x69, 0x01]] {
            let version = try await FakeDevice(replies: [Data(statusWord)]).link.open(.ton)

            XCTAssertNil(version)
        }
    }

    func testMissingAppFails() async {
        let device = FakeDevice(replies: [appInfo("BOLOS", "1.0.1"), Data([0x68, 0x07])])

        do {
            _ = try await device.link.open(.ethereum)
            XCTFail("A missing app must not read as still opening")
        } catch let error as LedgerStatusError {
            XCTAssertTrue(error.isAppMissing)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testDashboardNameIgnoresPadding() throws {
        let info = try LedgerAppInfo.parse(Data([0x01, 0x06]) + Data("BOLOS\0".utf8) + Data([0x01]) + Data("1".utf8))

        XCTAssertTrue(info.isDashboard)
    }
}

private let ok = Data([0x90, 0x00])

private func appInfo(_ name: String, _ version: String) -> Data {
    Data([0x01, UInt8(name.utf8.count)]) + Data(name.utf8) + Data([UInt8(version.utf8.count)]) + Data(version.utf8) + ok
}

/// Answers each exchange with the next reply and records what was sent.
actor FakeDevice {
    private var replies: [Data]
    private(set) var sent: [String] = []

    init(replies: [Data]) {
        self.replies = replies
    }

    nonisolated var link: LedgerLink {
        LedgerLink(exchange: { try await self.reply(to: $0) }, disconnected: AsyncStream { $0.finish() }, close: {})
    }

    private func reply(to apdu: Data) throws -> Data {
        sent.append(apdu.map { String(format: "%02x", $0) }.joined())
        guard !replies.isEmpty else {
            throw LedgerTransportError.disconnected
        }
        return replies.removeFirst()
    }
}

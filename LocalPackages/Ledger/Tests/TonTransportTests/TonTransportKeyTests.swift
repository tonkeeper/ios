@testable import LedgerKit
import TonSwift
@testable import TonTransport
import XCTest

final class TonTransportKeyTests: XCTestCase {
    private let walletKey = PublicKey(data: Data(repeating: 0x01, count: 32))
    private let otherKey = Data(repeating: 0x02, count: 32) + Data([0x90, 0x00])

    func testATransactionIsNotSentToALedgerWithAnotherKey() async throws {
        let device = FakeDevice(replies: [otherKey])

        do {
            _ = try await TonTransport(link: device.link)
                .signTransaction(path: AccountPath(index: 0), publicKey: walletKey, transaction: TransactionFixtures.jettonTransfer())
            XCTFail("A Ledger unlocked with another seed must not be asked to sign")
        } catch TonTransportError.publicKeyMismatch {
            let sent = await device.sent
            XCTAssertEqual(sent.count, 1)
        }
    }

    func testAProofIsNotSentToALedgerWithAnotherKey() async throws {
        let device = FakeDevice(replies: [otherKey])

        do {
            _ = try await TonTransport(link: device.link)
                .signAddressProof(path: AccountPath(index: 0), publicKey: walletKey, domain: "example.com", timestamp: 0, payload: "")
            XCTFail("A Ledger unlocked with another seed must not be asked to sign")
        } catch TonTransportError.publicKeyMismatch {
            let sent = await device.sent
            XCTAssertEqual(sent.count, 1)
        }
    }
}

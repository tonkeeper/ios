@testable import TonTransport
import XCTest

final class TransactionKnownJettonTests: XCTestCase {
    func testSettingKnownJettonOnJettonTransfer() {
        let known = KnownJetton(jettonId: 3, workchain: 0)
        let transaction = TransactionFixtures.jettonTransfer(queryId: 5).settingKnownJetton(known)
        guard case let .jettonTransfer(payload) = transaction.payload else {
            return XCTFail("payload kind must be preserved")
        }
        XCTAssertEqual(payload.knownJetton, known)
        XCTAssertEqual(payload.queryId, 5)
        XCTAssertEqual(transaction.seqno, 7)
    }

    func testSettingKnownJettonLeavesOtherPayloadsUntouched() {
        let transaction = TransactionFixtures.comment("hi").settingKnownJetton(KnownJetton(jettonId: 0, workchain: 0))
        guard case let .comment(text) = transaction.payload else {
            return XCTFail("payload kind must be preserved")
        }
        XCTAssertEqual(text, "hi")
    }

    func testTxParsingFailedStatusCode() {
        guard case .txParsingFailed = TransportStatusError.fromStatusCode(0xB010) else {
            return XCTFail("0xB010 must map to txParsingFailed")
        }
        guard case .deniedByUser = TransportStatusError.fromStatusCode(0x6985) else {
            return XCTFail("0x6985 must still map to deniedByUser")
        }
    }
}

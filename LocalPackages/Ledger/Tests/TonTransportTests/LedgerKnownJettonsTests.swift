import TonSwift
@testable import TonTransport
import XCTest

final class LedgerKnownJettonsTests: XCTestCase {
    func testListMatchesLedgerAppOrder() throws {
        XCTAssertEqual(LedgerKnownJettons.entries.count, 10)
        XCTAssertEqual(try LedgerKnownJettons.jettonId(master: Address.parse("EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs")), 0)
        XCTAssertEqual(try LedgerKnownJettons.jettonId(master: Address.parse("EQB4zZusHsbU2vVTPqjhlokIOoiZhEdCMT703CWEzhTOo__X")), 9)
    }

    func testTgBTCIsNotInTheDeviceTable() throws {
        XCTAssertNil(try LedgerKnownJettons.jettonId(master: Address.parse("EQBmjxpYsJ8yHEraYfTpLdejCekHMoKS2fOErP4lLHCf4SlU")))
    }

    func testMinAppVersionPerJetton() {
        XCTAssertEqual(LedgerKnownJettons.minAppVersion(jettonId: 0), "2.3.0")
        XCTAssertEqual(LedgerKnownJettons.minAppVersion(jettonId: 6), "2.3.0")
        XCTAssertEqual(LedgerKnownJettons.minAppVersion(jettonId: 7), "2.6.1")
        XCTAssertEqual(LedgerKnownJettons.minAppVersion(jettonId: 9), "2.6.1")
        XCTAssertNil(LedgerKnownJettons.minAppVersion(jettonId: 10))
    }

    func testRawFormOfTheSameMasterMatches() throws {
        let usdt = try Address.parse("0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe")
        XCTAssertEqual(LedgerKnownJettons.jettonId(master: usdt), 0)
    }

    func testUnknownMasterHasNoId() {
        XCTAssertNil(LedgerKnownJettons.jettonId(master: TransactionFixtures.receiver))
    }
}

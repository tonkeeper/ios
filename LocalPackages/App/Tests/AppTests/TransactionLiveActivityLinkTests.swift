@testable import App
import XCTest

final class TransactionLiveActivityLinkTests: XCTestCase {
    func test_roundTripsIdsThatCarryReservedCharacters() throws {
        let link = TransactionLiveActivityLink(walletId: "wallet 1&2", transactionId: "swap:ton:ab+cd/ef=")

        let url = try XCTUnwrap(link.url)

        XCTAssertEqual(TransactionLiveActivityLink(url: url), link)
    }

    func test_leavesOtherLinksToTheDeeplinkParser() throws {
        for string in [
            "tonkeeper://history",
            "tonkeeper://action?eventId=abc",
            "tonkeeper://live-activity?wallet_id=w",
            "ton://live-activity?wallet_id=w&transaction_id=t",
            "https://app.tonkeeper.com/live-activity?wallet_id=w&transaction_id=t",
        ] {
            XCTAssertNil(try TransactionLiveActivityLink(url: XCTUnwrap(URL(string: string))), string)
        }
    }
}

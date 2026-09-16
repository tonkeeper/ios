@testable import KeeperCore
import XCTest

final class TronHistoryPaginationTests: XCTestCase {
    func test_batteryCursorMovesStrictlyBelowTheOldestCollectedEvent() {
        let next = TronUSDTAPI.nextBatteryHistoryPageMaxTimestamp(
            pageCount: 20,
            limit: 20,
            oldestTimestamp: 1_786_520_976,
            finishTimestamp: 1_780_000_000
        )

        XCTAssertEqual(next, 1_786_520_975)
    }

    func test_batteryCursorStopsOnPageShorterThanLimit() {
        XCTAssertNil(
            TronUSDTAPI.nextBatteryHistoryPageMaxTimestamp(
                pageCount: 1,
                limit: 20,
                oldestTimestamp: 1_786_520_976,
                finishTimestamp: 1_780_000_000
            )
        )
    }

    func test_batteryCursorStopsOncePageReachesFinishTimestamp() {
        XCTAssertNil(
            TronUSDTAPI.nextBatteryHistoryPageMaxTimestamp(
                pageCount: 20,
                limit: 20,
                oldestTimestamp: 1_780_000_000,
                finishTimestamp: 1_780_000_000
            )
        )
    }

    /// Every step lowers the bound, so a full-page walk always converges on `finishTimestamp`.
    func test_walkTerminates() {
        var maxTimestamp: Int64? = 1_000_010
        var steps = 0

        while let current = maxTimestamp, steps < 100 {
            steps += 1
            maxTimestamp = TronUSDTAPI.nextBatteryHistoryPageMaxTimestamp(
                pageCount: 20,
                limit: 20,
                oldestTimestamp: current,
                finishTimestamp: 1_000_000
            )
        }

        XCTAssertNil(maxTimestamp)
        XCTAssertEqual(steps, 11)
    }

    func test_tronGridUsesFingerprintForFullPage() {
        XCTAssertEqual(
            TronUSDTAPI.nextTronHistoryFingerprint(
                pageCount: 20,
                limit: 20,
                fingerprint: "next"
            ),
            "next"
        )
    }

    func test_tronGridStopsOnShortPageOrWithoutFingerprint() {
        XCTAssertNil(
            TronUSDTAPI.nextTronHistoryFingerprint(
                pageCount: 19,
                limit: 20,
                fingerprint: "next"
            )
        )
        XCTAssertNil(
            TronUSDTAPI.nextTronHistoryFingerprint(
                pageCount: 20,
                limit: 20,
                fingerprint: nil
            )
        )
    }
}

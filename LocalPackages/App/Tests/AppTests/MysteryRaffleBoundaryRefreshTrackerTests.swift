@testable import App
import Foundation
import XCTest

final class MysteryRaffleBoundaryRefreshTrackerTests: XCTestCase {
    func test_lateOpenRefreshesAlreadyPastContentBoundariesOnlyOnce() {
        let now = Date(timeIntervalSince1970: 100)
        let boundaries: [MysteryRaffleBoundaryRefreshTracker.DatedBoundary] = [
            (.startsAt, now.addingTimeInterval(-20)),
            (.zeroFeeEndsAt, now.addingTimeInterval(-10)),
            (.endsAt, now.addingTimeInterval(100)),
        ]
        var tracker = MysteryRaffleBoundaryRefreshTracker()

        XCTAssertTrue(tracker.shouldRefresh(raffleId: "raffle", boundaries: boundaries, now: now))
        XCTAssertFalse(tracker.shouldRefresh(raffleId: "raffle", boundaries: boundaries, now: now))
    }

    func test_futureBoundaryRefreshesWhenCrossed() {
        let boundary = Date(timeIntervalSince1970: 100)
        let boundaries: [MysteryRaffleBoundaryRefreshTracker.DatedBoundary] = [(.startsAt, boundary)]
        var tracker = MysteryRaffleBoundaryRefreshTracker()

        XCTAssertFalse(tracker.shouldRefresh(raffleId: "raffle", boundaries: boundaries, now: boundary.addingTimeInterval(-1)))
        XCTAssertTrue(tracker.shouldRefresh(raffleId: "raffle", boundaries: boundaries, now: boundary))
        XCTAssertFalse(tracker.shouldRefresh(raffleId: "raffle", boundaries: boundaries, now: boundary))
    }

    func test_newRaffleAndChangedBoundaryDateRefreshAgain() {
        let now = Date(timeIntervalSince1970: 100)
        var tracker = MysteryRaffleBoundaryRefreshTracker()

        XCTAssertTrue(tracker.shouldRefresh(raffleId: "a", boundaries: [(.startsAt, now.addingTimeInterval(-2))], now: now))
        XCTAssertTrue(tracker.shouldRefresh(raffleId: "a", boundaries: [(.startsAt, now.addingTimeInterval(-1))], now: now))
        XCTAssertTrue(tracker.shouldRefresh(raffleId: "b", boundaries: [(.startsAt, now.addingTimeInterval(-1))], now: now))
    }
}

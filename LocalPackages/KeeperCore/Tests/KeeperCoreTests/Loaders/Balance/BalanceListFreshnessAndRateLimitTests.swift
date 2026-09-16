import Foundation
@testable import KeeperCore
import XCTest

final class TonAPIRateLimitBackoffTests: XCTestCase {
    func test_delayGrowsExponentiallyWithoutJitter() {
        let attempt0 = TonAPIRateLimitBackoff.delayNanoseconds(attempt: 0, jitter: 0)
        let attempt1 = TonAPIRateLimitBackoff.delayNanoseconds(attempt: 1, jitter: 0)
        let attempt2 = TonAPIRateLimitBackoff.delayNanoseconds(attempt: 2, jitter: 0)

        XCTAssertEqual(attempt0, 100_000_000)
        XCTAssertEqual(attempt1, 200_000_000)
        XCTAssertEqual(attempt2, 400_000_000)
    }

    /// Five attempts of exponential backoff, and nothing the server says can stretch them: a
    /// rate-limited request is bounded by the client alone.
    func test_theWholeRetryChainStaysUnderFourSeconds() {
        let worstCase = (0 ..< TonAPIRateLimitBackoff.maxRetryCount)
            .map { TonAPIRateLimitBackoff.delayNanoseconds(attempt: $0, jitter: 0.25) }
            .reduce(0, +)

        XCTAssertLessThan(worstCase, 4_000_000_000)
    }
}

final class WalletBalanceStateListFreshnessTests: XCTestCase {
    func test_previousAlwaysNeedsRefresh() {
        let state = WalletBalanceState.previous(makeBalance(date: Date()))
        XCTAssertTrue(state.needsListRefresh(freshnessInterval: 60))
    }

    func test_currentSkipsWhenFresh() {
        let now = Date()
        let state = WalletBalanceState.current(makeBalance(date: now.addingTimeInterval(-30)))
        XCTAssertFalse(state.needsListRefresh(at: now, freshnessInterval: 60))
    }

    private func makeBalance(date: Date) -> WalletBalance {
        WalletBalance(
            date: date,
            balance: Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: []),
            stacking: [],
            batteryBalance: nil,
            tronBalance: nil
        )
    }
}

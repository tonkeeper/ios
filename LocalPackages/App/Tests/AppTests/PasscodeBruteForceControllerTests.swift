@testable import App
import TKCore
import XCTest

final class PasscodeBruteForceControllerTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_000_000)

    private func makeController(
        store: FakeBruteForceStore,
        analytics: FakeLockoutAnalytics = FakeLockoutAnalytics(),
        from: PasscodeLockout.From = .confirmation,
        policy: PasscodeLockoutPolicy = .default
    ) -> PasscodeBruteForceController {
        PasscodeBruteForceController(store: store, analytics: analytics, from: from, policy: policy, now: { [fixedNow] in fixedNow })
    }

    // MARK: - registerFailure: counting

    func test_registerFailure_incrementsAndPersists() async {
        let store = FakeBruteForceStore(failedAttempts: 0)
        let controller = makeController(store: store)

        _ = await controller.registerFailure()
        XCTAssertEqual(store.failedAttempts, 1)

        _ = await controller.registerFailure()
        XCTAssertEqual(store.failedAttempts, 2)
    }

    // MARK: - registerFailure: counter hint visibility (counts down to the lockout)

    func test_registerFailure_hidesCounterWhileMoreThanTwoLeft() async {
        // -> 3: lockout fires on the 6th, so 3 attempts still remain → counter stays hidden.
        let store = FakeBruteForceStore(failedAttempts: 2)
        let outcome = await makeController(store: store).registerFailure()
        XCTAssertNil(outcome.attemptsLeft)
    }

    func test_registerFailure_showsTwoLeft() async {
        let store = FakeBruteForceStore(failedAttempts: 3)
        let outcome = await makeController(store: store).registerFailure() // -> 4: two attempts before lockout
        XCTAssertEqual(outcome.attemptsLeft, 2)
    }

    func test_registerFailure_showsOneLeftOnLastFreeAttempt() async {
        let store = FakeBruteForceStore(failedAttempts: 4)
        let analytics = FakeLockoutAnalytics()
        let outcome = await makeController(store: store, analytics: analytics).registerFailure() // -> 5

        XCTAssertEqual(outcome.attemptsLeft, 1, "Last free attempt: the next wrong entry locks")
        XCTAssertNil(outcome.lockoutEndDate, "5th failure is still free; the lockout starts on the 6th")
        XCTAssertTrue(analytics.events.isEmpty)
    }

    // MARK: - registerFailure: first lockout + analytics

    func test_registerFailure_firstLockout_setsLockoutAndLogsAnalytics() async {
        let store = FakeBruteForceStore(failedAttempts: 5)
        let analytics = FakeLockoutAnalytics()
        let outcome = await makeController(store: store, analytics: analytics, from: .unlock).registerFailure() // -> 6

        XCTAssertEqual(outcome.lockoutEndDate, fixedNow.addingTimeInterval(30))
        XCTAssertNil(outcome.attemptsLeft, "Counter is hidden once a lockout fires")
        XCTAssertEqual(store.lockoutEndDate, fixedNow.addingTimeInterval(30))
        XCTAssertEqual(analytics.events.count, 1)
        XCTAssertEqual(analytics.events.first?.from, .unlock)
        XCTAssertEqual(analytics.events.first?.durationSeconds, 30)
        XCTAssertEqual(analytics.events.first?.failedAttempts, 6)
    }

    func test_registerFailure_withinFreeWindow_noLockoutNoAnalytics() async {
        let store = FakeBruteForceStore(failedAttempts: 2)
        let analytics = FakeLockoutAnalytics()
        let outcome = await makeController(store: store, analytics: analytics).registerFailure() // -> 3

        XCTAssertNil(outcome.lockoutEndDate)
        XCTAssertNil(store.lockoutEndDate)
        XCTAssertTrue(analytics.events.isEmpty)
    }

    func test_registerFailure_escalatesAcrossBands() async {
        // Every failure past the free window locks; the duration steps up per 5-attempt band.
        let cases: [(priorAttempts: Int, expectedSeconds: TimeInterval)] = [
            (5, 30), // -> 6:  6–10  → 30s
            (10, 120), // -> 11: 11–15 → 2m
            (15, 300), // -> 16: 16–20 → 5m
            (20, 900), // -> 21: 21–29 → 15m
            (28, 900), // -> 29: still 21–29
            (29, 3600), // -> 30: 30+   → 60m
            (50, 3600), // -> 51: capped
        ]
        for c in cases {
            let store = FakeBruteForceStore(failedAttempts: c.priorAttempts)
            let outcome = await makeController(store: store).registerFailure()
            XCTAssertEqual(
                outcome.lockoutEndDate, fixedNow.addingTimeInterval(c.expectedSeconds),
                "after \(c.priorAttempts + 1) failures expected \(c.expectedSeconds)s lockout"
            )
        }
    }

    // MARK: - registerSuccess

    func test_registerSuccess_resetsCounterAndLockout() async {
        let store = FakeBruteForceStore(failedAttempts: 4, lockoutEndDate: fixedNow.addingTimeInterval(30))
        await makeController(store: store).registerSuccess()
        XCTAssertEqual(store.failedAttempts, 0)
        XCTAssertNil(store.lockoutEndDate)
        XCTAssertEqual(store.setCallCount, 1)
    }

    func test_registerSuccess_noOpWhenAlreadyClean() async {
        let store = FakeBruteForceStore(failedAttempts: 0, lockoutEndDate: nil)
        await makeController(store: store).registerSuccess()
        XCTAssertEqual(store.setCallCount, 0, "Avoids a redundant persistence write when nothing changed")
    }

    // MARK: - activeLockoutEndDate

    func test_activeLockoutEndDate_nilWhenNoDate() {
        let store = FakeBruteForceStore(failedAttempts: 3, lockoutEndDate: nil)
        XCTAssertNil(makeController(store: store).activeLockoutEndDate())
    }

    func test_activeLockoutEndDate_nilWhenExpired() {
        let store = FakeBruteForceStore(failedAttempts: 6, lockoutEndDate: fixedNow.addingTimeInterval(-1))
        XCTAssertNil(makeController(store: store).activeLockoutEndDate())
    }

    func test_activeLockoutEndDate_returnsWhenActive() {
        let end = fixedNow.addingTimeInterval(20)
        let store = FakeBruteForceStore(failedAttempts: 6, lockoutEndDate: end)
        XCTAssertEqual(makeController(store: store).activeLockoutEndDate(), end)
    }

    func test_activeLockoutEndDate_clampsBackwardClockJump() {
        // Wall clock jumped backward: the stored end is beyond any policy lockout (max 3600s).
        let store = FakeBruteForceStore(failedAttempts: 6, lockoutEndDate: fixedNow.addingTimeInterval(7200))
        XCTAssertEqual(makeController(store: store).activeLockoutEndDate(), fixedNow.addingTimeInterval(3600))
    }
}

private final class FakeBruteForceStore: PasscodeBruteForceStore {
    var failedAttempts: Int
    var lockoutEndDate: Date?
    private(set) var setCallCount = 0

    init(failedAttempts: Int = 0, lockoutEndDate: Date? = nil) {
        self.failedAttempts = failedAttempts
        self.lockoutEndDate = lockoutEndDate
    }

    func bruteForceState() -> (failedAttempts: Int, lockoutEndDate: Date?) {
        (failedAttempts, lockoutEndDate)
    }

    func setBruteForce(failedAttempts: Int, lockoutEndDate: Date?) async {
        setCallCount += 1
        self.failedAttempts = failedAttempts
        self.lockoutEndDate = lockoutEndDate
    }
}

private final class FakeLockoutAnalytics: PasscodeLockoutAnalytics {
    private(set) var events: [(from: PasscodeLockout.From, durationSeconds: Int, failedAttempts: Int)] = []

    func logPasscodeLockout(from: PasscodeLockout.From, durationSeconds: Int, failedAttempts: Int) {
        events.append((from: from, durationSeconds: durationSeconds, failedAttempts: failedAttempts))
    }
}

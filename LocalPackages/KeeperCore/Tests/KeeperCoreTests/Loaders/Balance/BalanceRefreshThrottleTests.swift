import Foundation
@testable import KeeperCore
import XCTest

final class BalanceRefreshThrottleDecisionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1000)

    func test_firstRequestStartsImmediately() {
        XCTAssertEqual(decision(lastRunDate: nil), .start)
    }

    /// A run that started before this request may have read the backend before the change it
    /// reports was indexed, so it earns exactly one follow-up.
    func test_requestDuringARunCoalescesIntoOneFollowUp() {
        XCTAssertEqual(decision(isRunning: true, lastRunDate: now), .coalesce)
    }

    /// A screen appearing over a run already fetching what it wants is answered by that run, so it
    /// must not queue a second one behind it.
    func test_requestThatRidesTheRunInFlightQueuesNothing() {
        XCTAssertEqual(
            decision(isRunning: true, earnsFollowUp: false, lastRunDate: now),
            .skip
        )
    }

    func test_requestIsDroppedWhileAnotherIsQueued() {
        XCTAssertEqual(decision(isFollowUpPending: true, lastRunDate: now), .skip)
    }

    func test_queuedWaitIsKeptWhenItAlreadyLandsSoonEnough() {
        XCTAssertEqual(
            decision(scheduledWake: now.addingTimeInterval(1), lastRunDate: now.addingTimeInterval(-1)),
            .skip
        )
    }

    /// The floor a person waiting on the screen is held to, rather than the one the stream is paced
    /// by: 100ms after an automatic reload, a pull-to-refresh waits out 400ms, not 4.9s.
    func test_aManualRequestIsPacedByItsOwnShorterFloor() {
        guard case let .schedule(after) = decision(
            lastRunDate: now.addingTimeInterval(-0.1),
            minInterval: 0.5
        ) else {
            return XCTFail("expected the request to be scheduled")
        }
        XCTAssertEqual(after, 0.4, accuracy: 0.001)
    }

    /// Entering a hot window shortens the interval under a wait already queued on the regular one,
    /// and the send that opened the window must not have to sit out the old remainder.
    func test_aShorterIntervalReplacesTheQueuedWait() {
        XCTAssertEqual(
            decision(
                scheduledWake: now.addingTimeInterval(4),
                lastRunDate: now.addingTimeInterval(-1),
                minInterval: 2
            ),
            .schedule(after: 1)
        )
    }

    private func decision(
        isRunning: Bool = false,
        isFollowUpPending: Bool = false,
        earnsFollowUp: Bool = true,
        scheduledWake: Date? = nil,
        lastRunDate: Date?,
        minInterval: TimeInterval = 5
    ) -> BalanceRefreshThrottle.Decision {
        BalanceRefreshThrottle.decision(
            isRunning: isRunning,
            isFollowUpPending: isFollowUpPending,
            earnsFollowUp: earnsFollowUp,
            scheduledWake: scheduledWake,
            lastRunDate: lastRunDate,
            now: now,
            minInterval: minInterval
        )
    }
}

/// TK-2837: migrating a 50+ asset wallet produced a streaming update every couple of seconds, and
/// each one used to become its own reload.
final class BalanceRefreshThrottleBehaviourTests: XCTestCase {
    func test_burstDuringARunProducesOneFollowUp() async {
        let clock = ThrottleTestClock()
        let sleeper = ThrottleTestSleeper()
        let run = ThrottleTestRun()
        let throttle = makeThrottle(clock: clock, sleeper: sleeper, run: run)

        await run.awaitStart { throttle.request(priority: .background) }
        for _ in 0 ..< 25 {
            throttle.request(priority: .background)
        }
        XCTAssertEqual(run.startedCount, 1, "a burst must not start a second run")

        await run.finishAndAwaitNextStart(sleeper: sleeper, clock: clock)

        XCTAssertEqual(run.startedCount, 2, "the burst collapses into exactly one follow-up")
    }

    /// A cancelled run keeps going when its awaits do not observe cancellation — the reload parks on
    /// the deliberately uncancellable shared rates load — and lands after its replacement started.
    /// Its completion must not report the replacement as finished, or the next request starts a
    /// second reload alongside it.
    func test_aCancelledRunLandingLateDoesNotFreeTheThrottle() async {
        let clock = ThrottleTestClock()
        let sleeper = ThrottleTestSleeper()
        let run = UncancellableRun()
        let throttle = BalanceRefreshThrottle(
            minInterval: 5,
            now: { clock.now() },
            sleep: { try await sleeper.sleep(delay: $0) },
            operation: { _ in await run.perform() }
        )

        await run.awaitStart(count: 1) { throttle.request(priority: .background) }
        throttle.cancel()

        clock.advance(by: 5)
        await run.awaitStart(count: 2) { throttle.request(priority: .background) }
        throttle.request(priority: .background)

        let noThirdRun = expectation(description: "no run beside the one in flight")
        noThirdRun.isInverted = true
        run.didStart = { noThirdRun.fulfill() }

        clock.advance(by: 5)
        run.finishOldest()
        await fulfillment(of: [noThirdRun], timeout: 0.05)

        XCTAssertEqual(
            run.startedCount,
            2,
            "the replacement is still in flight, so its follow-up must wait for it"
        )
    }

    /// Entering a hot window shrinks the interval under a wait queued on the regular one. The queued
    /// wait has to be retired rather than left to fire a second run behind the one it overtook.
    func test_aShrunkIntervalRetiresTheWaitItOvertakes() async {
        let clock = ThrottleTestClock()
        let sleeper = ThrottleTestSleeper()
        let run = ThrottleTestRun()
        let interval = LockedInterval(5)
        let throttle = BalanceRefreshThrottle(
            minInterval: { _ in interval.value },
            now: { clock.now() },
            sleep: { try await sleeper.sleep(delay: $0) },
            operation: { _ in await run.perform() }
        )

        await run.awaitStart { throttle.request(priority: .background) }
        run.finish()
        await Task.yield()

        clock.advance(by: 1)
        let scheduled = expectation(description: "queued on the regular interval")
        sleeper.onNextSleep { scheduled.fulfill() }
        throttle.request(priority: .background)
        await fulfillment(of: [scheduled], timeout: 1)
        XCTAssertEqual(sleeper.delays, [4])

        clock.advance(by: 2)
        interval.value = 2
        await run.awaitStart { throttle.request(priority: .background) }
        XCTAssertEqual(run.startedCount, 2, "the send starts its reload instead of waiting out 4s")

        // Let that reload finish and the interval elapse, so an overtaken wait waking up here would
        // have every reason to start a run of its own.
        run.finish()
        await Task.yield()
        clock.advance(by: 2)

        let noThirdRun = expectation(description: "no run from the overtaken wait")
        noThirdRun.isInverted = true
        run.didStart = { noThirdRun.fulfill() }
        sleeper.resumeNext()
        await fulfillment(of: [noThirdRun], timeout: 0.05)

        XCTAssertEqual(run.startedCount, 2, "the overtaken wait must not fire a run of its own")
    }

    /// A request someone is waiting on arriving while a background run is in flight coalesces onto
    /// it. When that run ends the follow-up is the person's, so it is paced by their shorter floor —
    /// not held back to five seconds from a run they did not ask for.
    func test_aWaitedOnRequestCoalescedOntoABackgroundRunKeepsItsOwnFloor() async {
        let clock = ThrottleTestClock()
        let sleeper = ThrottleTestSleeper()
        let run = ThrottleTestRun()
        let throttle = BalanceRefreshThrottle(
            minInterval: { priority in priority > .background ? 0.5 : 5 },
            now: { clock.now() },
            sleep: { try await sleeper.sleep(delay: $0) },
            operation: { _ in await run.perform() }
        )

        await run.awaitStart { throttle.request(priority: .background) }
        throttle.request(priority: .userInitiated)

        clock.advance(by: 1)
        await run.awaitStart { run.finish() }

        XCTAssertEqual(run.startedCount, 2, "1s past the background run clears the shorter floor")
        XCTAssertTrue(sleeper.delays.isEmpty, "so the follow-up does not wait at all")
    }

    /// A request that rides the run in flight registers its wait through the throttle, and can do
    /// so in the moment between that run settling and the throttle noticing it is over. Nothing is
    /// queued to answer it, so the throttle has to say so.
    func test_aRunThatEndsWithNothingQueuedSaysTheThrottleIsIdle() async {
        let clock = ThrottleTestClock()
        let sleeper = ThrottleTestSleeper()
        let run = ThrottleTestRun()
        let throttle = makeThrottle(clock: clock, sleeper: sleeper, run: run)
        let idle = expectation(description: "throttle reports idle")
        throttle.onIdle = { idle.fulfill() }

        await run.awaitStart { throttle.request(priority: .background) }
        run.finish()

        await fulfillment(of: [idle], timeout: 1)
    }

    /// The queued run answers whoever the one that just ended did not, so its end is not the
    /// throttle falling idle.
    func test_aRunWithAFollowUpBehindItDoesNotSayTheThrottleIsIdle() async {
        let clock = ThrottleTestClock()
        let sleeper = ThrottleTestSleeper()
        let run = ThrottleTestRun()
        let throttle = makeThrottle(clock: clock, sleeper: sleeper, run: run)
        let idle = expectation(description: "throttle reports idle")
        idle.isInverted = true
        throttle.onIdle = { idle.fulfill() }

        await run.awaitStart { throttle.request(priority: .background) }
        throttle.request(priority: .background)

        let scheduled = expectation(description: "follow-up queued")
        sleeper.onNextSleep { scheduled.fulfill() }
        run.finish()
        await fulfillment(of: [scheduled], timeout: 1)

        await fulfillment(of: [idle], timeout: 0.05)
    }

    /// A cancelled run lands after whatever replaced it took the throttle, so it speaks for nobody
    /// — least of all about the throttle being free.
    func test_aCancelledRunDoesNotSayTheThrottleIsIdle() async {
        let clock = ThrottleTestClock()
        let sleeper = ThrottleTestSleeper()
        let run = ThrottleTestRun()
        let throttle = makeThrottle(clock: clock, sleeper: sleeper, run: run)
        let idle = expectation(description: "throttle reports idle")
        idle.isInverted = true
        throttle.onIdle = { idle.fulfill() }

        await run.awaitStart { throttle.request(priority: .background) }
        throttle.cancel()
        run.finish()

        await fulfillment(of: [idle], timeout: 0.05)
    }

    private func makeThrottle(
        clock: ThrottleTestClock,
        sleeper: ThrottleTestSleeper,
        run: ThrottleTestRun,
        minInterval: TimeInterval = 5
    ) -> BalanceRefreshThrottle {
        BalanceRefreshThrottle(
            minInterval: minInterval,
            now: { clock.now() },
            sleep: { try await sleeper.sleep(delay: $0) },
            operation: { _ in await run.perform() }
        )
    }
}

/// A run whose awaits do not observe cancellation, so cancelling it only detaches it: it keeps
/// running and completes on its own schedule.
private final class UncancellableRun: @unchecked Sendable {
    var didStart: (() -> Void)?

    private let lock = NSLock()
    private var continuations = [CheckedContinuation<Void, Never>]()
    private var started = 0

    var startedCount: Int {
        lock.withLock { started }
    }

    func perform() async {
        await withCheckedContinuation { continuation in
            let handler = lock.withLock { () -> (() -> Void)? in
                continuations.append(continuation)
                started += 1
                return didStart
            }
            handler?()
        }
    }

    func finishOldest() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            continuations.isEmpty ? nil : continuations.removeFirst()
        }
        continuation?.resume()
    }

    func awaitStart(count: Int, _ trigger: () -> Void) async {
        let started = XCTestExpectation(description: "run \(count) started")
        didStart = { [weak self] in
            if self?.startedCount == count { started.fulfill() }
        }
        trigger()
        _ = await XCTWaiter().fulfillment(of: [started], timeout: 1)
    }
}

private final class LockedInterval: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: TimeInterval

    init(_ value: TimeInterval) {
        stored = value
    }

    var value: TimeInterval {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private final class ThrottleTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var offset: TimeInterval = 0

    func now() -> Date {
        Date(timeIntervalSince1970: 1000 + lock.withLock { offset })
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { offset += interval }
    }
}

private final class ThrottleTestSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [CheckedContinuation<Void, Never>]()
    private var recordedDelays = [TimeInterval]()
    private var nextSleepHandler: (() -> Void)?

    var delays: [TimeInterval] {
        lock.withLock { recordedDelays }
    }

    func onNextSleep(_ handler: @escaping () -> Void) {
        lock.withLock { nextSleepHandler = handler }
    }

    func sleep(delay: TimeInterval) async throws {
        await withCheckedContinuation { continuation in
            let handler = lock.withLock { () -> (() -> Void)? in
                continuations.append(continuation)
                recordedDelays.append(delay)
                defer { nextSleepHandler = nil }
                return nextSleepHandler
            }
            handler?()
        }
    }

    func resumeNext() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            continuations.isEmpty ? nil : continuations.removeFirst()
        }
        continuation?.resume()
    }
}

private final class ThrottleTestRun: @unchecked Sendable {
    var didStart: (() -> Void)?
    var onCancel: (() -> Void)?

    private let lock = NSLock()
    private var continuations = [CheckedContinuation<Void, Never>]()
    private var started = 0

    var startedCount: Int {
        lock.withLock { started }
    }

    func perform() async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let handler = lock.withLock { () -> (() -> Void)? in
                    continuations.append(continuation)
                    started += 1
                    return didStart
                }
                handler?()
            }
        } onCancel: {
            onCancel?()
            finish()
        }
    }

    func finish() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            continuations.isEmpty ? nil : continuations.removeFirst()
        }
        continuation?.resume()
    }
}

private extension ThrottleTestRun {
    func awaitStart(
        timeout: TimeInterval = 1,
        _ trigger: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let started = XCTestExpectation(description: "run started")
        didStart = { started.fulfill() }
        trigger()
        let result = await XCTWaiter().fulfillment(of: [started], timeout: timeout)
        if result != .completed {
            XCTFail("run did not start", file: file, line: line)
        }
    }

    /// The follow-up is throttled too, so releasing it needs the clock moved past the interval.
    func finishAndAwaitNextStart(sleeper: ThrottleTestSleeper, clock: ThrottleTestClock) async {
        let scheduled = XCTestExpectation(description: "follow-up scheduled")
        sleeper.onNextSleep { scheduled.fulfill() }
        finish()
        _ = await XCTWaiter().fulfillment(of: [scheduled], timeout: 1)
        clock.advance(by: 5)
        await awaitStart { sleeper.resumeNext() }
    }
}

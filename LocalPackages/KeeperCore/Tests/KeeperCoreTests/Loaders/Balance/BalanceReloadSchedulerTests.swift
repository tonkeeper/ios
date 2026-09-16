import Foundation
@testable import KeeperCore
import XCTest

final class BalanceReloadSchedulerTests: XCTestCase {
    func test_schedulerStartsQuietUntilTheAppIsActive() {
        let harness = Harness()
        XCTAssertEqual(harness.scheduler.mode, .quiet)
        XCTAssertEqual(harness.sleeper.delays, [])
    }

    func test_activeAppTicksOnTheIdleInterval() async {
        let harness = Harness()
        await harness.awaitSleep { harness.becomeActive() }
        XCTAssertEqual(harness.sleeper.delays, [30])
        XCTAssertEqual(harness.scheduler.mode, .regular)
    }

    func test_regularPollingPauseStopsIdleTicks() async {
        let harness = Harness()
        await harness.awaitSleep { harness.becomeActive() }
        harness.scheduler.setRegularPollingPaused(true)
        XCTAssertEqual(harness.scheduler.mode, .regular)
        XCTAssertEqual(harness.sleeper.delays, [30], "pause cancels the idle sleep without starting another")
    }

    func test_regularPollingPauseKeepsHotWindowTicks() async {
        let harness = Harness()
        harness.becomeActive()
        harness.scheduler.setRegularPollingPaused(true)
        await harness.awaitSleep { harness.scheduler.enterHotWindow() }
        XCTAssertEqual(harness.scheduler.mode, .hot)
        XCTAssertEqual(harness.sleeper.delays.last, 2)
    }

    func test_hotWindowTicksOnTheFastInterval() async {
        let harness = Harness()
        harness.becomeActive()
        await harness.awaitSleep { harness.scheduler.enterHotWindow() }
        XCTAssertEqual(harness.scheduler.mode, .hot)
        XCTAssertEqual(harness.sleeper.delays.last, 2)
    }

    /// The reason silence is a set of owners: backgrounding and returning must not speak for a flow
    /// that is still holding the budget.
    func test_lifecycleReturnDoesNotBreakAFlowsSilence() async {
        let harness = Harness()
        await harness.awaitSleep { harness.becomeActive() }
        harness.scheduler.setQuiet(true, owner: .flow(id: "migration"))
        harness.scheduler.setQuiet(true, owner: .appLifecycle)

        harness.scheduler.setQuiet(false, owner: .appLifecycle)

        XCTAssertEqual(harness.scheduler.mode, .quiet, "the flow still needs the request budget")
    }

    /// Releasing silence says "stop being quiet", not "stop being interested" — this is what keeps
    /// the fast refresh after a migration alive across the dismissal.
    func test_releasingSilenceDoesNotCloseAnOpenHotWindow() async {
        let harness = Harness()
        harness.becomeActive()
        harness.scheduler.setQuiet(true, owner: .flow(id: "migration"))
        harness.scheduler.enterHotWindow()

        await harness.awaitSleep { harness.scheduler.setQuiet(false, owner: .flow(id: "migration")) }

        XCTAssertEqual(harness.scheduler.mode, .hot)
        XCTAssertEqual(harness.sleeper.delays.last, 2)
    }
}

private final class Harness: @unchecked Sendable {
    let clock = SchedulerTestClock()
    let sleeper = SchedulerTestSleeper()
    let scheduler: BalanceReloadScheduler

    var onTick: (() -> Void)?

    private let lock = NSLock()
    private var ticks = 0

    var tickCount: Int {
        lock.withLock { ticks }
    }

    init() {
        scheduler = BalanceReloadScheduler(
            hotInterval: 2,
            regularInterval: 30,
            hotDuration: 14,
            now: { [clock] in clock.now() },
            sleep: { [sleeper] in try await sleeper.sleep(delay: $0) }
        )
        scheduler.onTick = { [weak self] in
            guard let self else { return }
            lock.withLock { self.ticks += 1 }
            self.onTick?()
        }
    }

    func becomeActive() {
        scheduler.setQuiet(false, owner: .appLifecycle)
    }

    func awaitSleep(
        timeout: TimeInterval = 1,
        _ trigger: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let slept = XCTestExpectation(description: "scheduler slept")
        sleeper.onNextSleep { slept.fulfill() }
        trigger()
        if await XCTWaiter().fulfillment(of: [slept], timeout: timeout) != .completed {
            XCTFail("scheduler did not reach a sleep", file: file, line: line)
        }
    }
}

private final class SchedulerTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var offset: TimeInterval = 0

    func now() -> Date {
        Date(timeIntervalSince1970: 1000 + lock.withLock { offset })
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { offset += interval }
    }
}

private final class SchedulerTestSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = [(id: Int, continuation: CheckedContinuation<Void, Never>)]()
    private var recordedDelays = [TimeInterval]()
    private var nextSleepHandler: (() -> Void)?
    private var nextID = 0

    var delays: [TimeInterval] {
        lock.withLock { recordedDelays }
    }

    func onNextSleep(_ handler: @escaping () -> Void) {
        lock.withLock { nextSleepHandler = handler }
    }

    /// Cancellation resumes the sleep that was cancelled, never whichever happens to be first: a
    /// replaced tick loop must not steal the wake-up belonging to the loop that replaced it.
    func sleep(delay: TimeInterval) async throws {
        let id = lock.withLock { () -> Int in
            nextID += 1
            return nextID
        }
        try await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let handler = lock.withLock { () -> (() -> Void)? in
                    pending.append((id, continuation))
                    recordedDelays.append(delay)
                    defer { nextSleepHandler = nil }
                    return nextSleepHandler
                }
                handler?()
            }
            try Task.checkCancellation()
        } onCancel: {
            resume(id: id)
        }
    }

    func resumeNext() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            pending.isEmpty ? nil : pending.removeFirst().continuation
        }
        continuation?.resume()
    }

    private func resume(id: Int) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            guard let index = pending.firstIndex(where: { $0.id == id }) else { return nil }
            return pending.remove(at: index).continuation
        }
        continuation?.resume()
    }
}

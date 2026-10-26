@testable import App
import XCTest

@available(iOS 16.2, *)
@MainActor
final class TransactionLiveActivityRefreshQueueTests: XCTestCase {
    func test_partialOutcomeWaitsForFullHandoffWithoutEnding() async {
        let queue = TransactionLiveActivityRefreshQueue()
        var log: [String] = []
        var release: CheckedContinuation<Void, Never>?
        let announced = expectation(description: "partial outcome announced")

        queue.schedule(after: 0) { finalization in
            finalization.set { log.append("end") }
            log.append("announce")
            await withCheckedContinuation {
                release = $0
                announced.fulfill()
            }
            log.append("handoff")
            finalization.clear()
        }
        await fulfillment(of: [announced], timeout: 1)
        XCTAssertEqual(log, ["announce"])

        release?.resume()
        await queue.waitForCurrent()
        XCTAssertEqual(log, ["announce", "handoff"])
    }

    func test_canceledPartialOutcomeEndsBeforeTheReplacementRefreshStarts() async {
        let queue = TransactionLiveActivityRefreshQueue()
        var log: [String] = []
        var releaseLoad: CheckedContinuation<Void, Never>?
        var releaseEnd: CheckedContinuation<Void, Never>?
        let announced = expectation(description: "partial outcome announced")
        let ending = expectation(description: "outcome being finalized")
        let replaced = expectation(description: "replacement ran")

        queue.schedule(after: 0) { finalization in
            finalization.set {
                log.append("ending")
                await withCheckedContinuation {
                    releaseEnd = $0
                    ending.fulfill()
                }
                log.append("ended")
            }
            log.append("announce")
            await withCheckedContinuation {
                releaseLoad = $0
                announced.fulfill()
            }
            guard !Task.isCancelled else { return }
            XCTFail("the partial refresh should have been cancelled")
        }
        await fulfillment(of: [announced], timeout: 1)

        queue.schedule(after: 0) { _ in
            log.append("replacement")
            replaced.fulfill()
        }
        releaseLoad?.resume()
        await fulfillment(of: [ending], timeout: 1)
        XCTAssertEqual(log, ["announce", "ending"])

        releaseEnd?.resume()
        await fulfillment(of: [replaced], timeout: 1)
        await queue.waitForCurrent()
        XCTAssertEqual(log, ["announce", "ending", "ended", "replacement"])
    }

    func test_earlyExitFinalizesBeforeBackgroundTimeIsReleased() async {
        let queue = TransactionLiveActivityRefreshQueue()
        var log: [String] = []

        queue.schedule(after: 0, onFinish: { log.append("release background time") }) { finalization in
            finalization.set { log.append("end") }
        }
        await queue.waitForCurrent()

        XCTAssertEqual(log, ["end", "release background time"])
    }

    func test_finalizationIsConsumedBeforeAReentrantFinish() async {
        let finalization = TransactionLiveActivityRefreshFinalization()
        var completions = 0
        finalization.set {
            completions += 1
            await finalization.finish()
        }

        await finalization.finish()
        await finalization.finish()

        XCTAssertEqual(completions, 1)
    }

    func test_replacementStartsOnlyAfterTheCanceledRefreshReturns() async {
        let queue = TransactionLiveActivityRefreshQueue()
        var log: [String] = []
        var release: CheckedContinuation<Void, Never>?
        let firstStarted = expectation(description: "first started")
        let secondRan = expectation(description: "second ran")

        queue.schedule(after: 0) { _ in
            log.append("first started")
            firstStarted.fulfill()
            await withCheckedContinuation { release = $0 }
            log.append("first returned canceled: \(Task.isCancelled)")
        }
        await fulfillment(of: [firstStarted], timeout: 1)

        queue.schedule(after: 0) { _ in
            log.append("second")
            secondRan.fulfill()
        }
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        XCTAssertEqual(log, ["first started"])

        release?.resume()
        await fulfillment(of: [secondRan], timeout: 1)
        XCTAssertEqual(log, ["first started", "first returned canceled: true", "second"])
    }

    func test_requestReplacedWhileWaitingNeverRuns() async {
        let queue = TransactionLiveActivityRefreshQueue()
        var log: [String] = []
        let secondRan = expectation(description: "second ran")

        queue.schedule(after: 60) { _ in log.append("first") }
        queue.schedule(after: 0) { _ in
            log.append("second")
            secondRan.fulfill()
        }

        await fulfillment(of: [secondRan], timeout: 1)
        XCTAssertEqual(log, ["second"])
    }

    func test_canceledRequestDoesNotRunAndLeavesQueueUsable() async {
        let queue = TransactionLiveActivityRefreshQueue()
        var log: [String] = []
        let nextRan = expectation(description: "next ran")

        queue.schedule(after: 60) { _ in log.append("canceled") }
        queue.cancel()
        queue.schedule(after: 0) { _ in
            log.append("next")
            nextRan.fulfill()
        }

        await fulfillment(of: [nextRan], timeout: 1)
        XCTAssertEqual(log, ["next"])
    }

    func test_waitForCurrentIncludesCanceledInFlightRefresh() async {
        let queue = TransactionLiveActivityRefreshQueue()
        var release: CheckedContinuation<Void, Never>?
        var didFinish = false
        let started = expectation(description: "refresh started")
        let waiting = expectation(description: "wait started")
        let finished = expectation(description: "refresh finished")

        queue.schedule(after: 0) { _ in
            await withCheckedContinuation {
                release = $0
                started.fulfill()
            }
        }
        await fulfillment(of: [started], timeout: 1)
        queue.cancel()
        let wait = Task {
            waiting.fulfill()
            await queue.waitForCurrent()
            didFinish = true
            finished.fulfill()
        }
        await fulfillment(of: [waiting], timeout: 1)
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        XCTAssertFalse(didFinish)
        release?.resume()
        await fulfillment(of: [finished], timeout: 1)
        await wait.value
    }
}

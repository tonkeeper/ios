import Foundation
@testable import KeeperCore
import XCTest

/// The repeat exists for a launch that happened offline: without it a single dropped connection
/// left the install unregistered until the next cold start. It must not turn into a loop over a
/// rejection the backend will repeat verbatim.
final class MultichainRetryTests: XCTestCase {
    func test_run_doesNotPauseWhenTheFirstPassSucceeds() async throws {
        let recorder = SleepRecorder()
        let calls = Counter()

        let value = try await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
            calls.increment()
        }

        XCTAssertEqual(value, 1)
        XCTAssertEqual(recorder.delays, [])
    }

    func test_run_repeatsATransientFailureUntilItSucceeds() async throws {
        let recorder = SleepRecorder()
        let calls = Counter()

        let value = try await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
            let attempt = calls.increment()
            guard attempt > 1 else { throw .connectionError }
            return attempt
        }

        XCTAssertEqual(value, 2)
        XCTAssertEqual(recorder.delays, [1])
    }

    func test_run_doesNotRepeatAnErrorTheBackendChose() async {
        let recorder = SleepRecorder()
        let calls = Counter()

        do {
            _ = try await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
                _ = calls.increment()
                throw .apiError(message: "wallet proof rejected")
            }
            XCTFail("expected the rejection to surface")
        } catch {
            XCTAssertEqual(calls.value, 1)
            XCTAssertEqual(recorder.delays, [])
        }
    }

    func test_run_stopsAtTheAttemptBoundAndSurfacesTheLastFailure() async {
        let recorder = SleepRecorder()
        let calls = Counter()

        do {
            _ = try await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
                _ = calls.increment()
                throw .connectionError
            }
            XCTFail("expected the failure to surface")
        } catch {
            XCTAssertEqual(calls.value, MultichainRetry.defaultAttempts)
            // One pause fewer than passes: the last failure is thrown instead of waited on.
            XCTAssertEqual(recorder.delays.count, MultichainRetry.defaultAttempts - 1)
        }
    }

    func test_delay_backsOffExponentiallyAndCaps() {
        XCTAssertEqual(MultichainRetry.delay(afterAttempt: 1), 1)
        XCTAssertEqual(MultichainRetry.delay(afterAttempt: 2), 2)
        XCTAssertEqual(MultichainRetry.delay(afterAttempt: 3), 4)
        XCTAssertEqual(MultichainRetry.delay(afterAttempt: 9), MultichainRetry.maxDelay)
    }

    /// A business call establishes the device session on its way out, and that ladder repeats too.
    /// Left alone the two would compound into `attempts²` transport attempts and their pauses on an
    /// offline start.
    func test_run_doesNotMultiplyAttemptsWhenNested() async {
        let recorder = SleepRecorder()
        let calls = Counter()

        do {
            _ = try await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
                try await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
                    _ = calls.increment()
                    throw .connectionError
                }
            }
            XCTFail("expected the failure to surface")
        } catch {
            XCTAssertEqual(calls.value, MultichainRetry.defaultAttempts)
            XCTAssertEqual(recorder.delays.count, MultichainRetry.defaultAttempts - 1)
        }
    }

    /// Shared work does not inherit the nesting of whoever started it: a task other callers join
    /// would otherwise spend a budget that depends on who won the race to create it.
    func test_run_keepsItsOwnBudgetWhenNestedAndOwningIt() async {
        let recorder = SleepRecorder()
        let calls = Counter()

        do {
            _ = try await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
                try await MultichainRetry.run(
                    owningBudget: true,
                    sleep: recorder.sleep
                ) { () async throws(MultichainServiceError) -> Int in
                    _ = calls.increment()
                    throw .connectionError
                }
            }
            XCTFail("expected the failure to surface")
        } catch {
            XCTAssertEqual(calls.value, MultichainRetry.defaultAttempts * MultichainRetry.defaultAttempts)
        }
    }

    func test_run_retriesOnItsOwnAgainAfterTheOuterRunReturned() async {
        let recorder = SleepRecorder()
        let calls = Counter()

        _ = try? await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
            try await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
                _ = calls.increment()
                throw .connectionError
            }
        }
        let nestedCalls = calls.value

        _ = try? await MultichainRetry.run(sleep: recorder.sleep) { () async throws(MultichainServiceError) -> Int in
            _ = calls.increment()
            throw .connectionError
        }

        XCTAssertEqual(calls.value - nestedCalls, MultichainRetry.defaultAttempts)
    }

    func test_cancellation_isNotSpentOnAnotherPass() async {
        let calls = Counter()
        let task = Task {
            try await MultichainRetry.run(sleep: { _ in }) { () async throws(MultichainServiceError) -> Int in
                _ = calls.increment()
                throw .connectionError
            }
        }
        task.cancel()
        _ = await task.result

        XCTAssertLessThanOrEqual(calls.value, 1)
    }
}

// MARK: -

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            count += 1
            return count
        }
    }
}

private final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded = [TimeInterval]()

    var delays: [TimeInterval] {
        lock.withLock { recorded }
    }

    var sleep: MultichainRetry.Sleep {
        { [self] seconds in
            lock.withLock { recorded.append(seconds) }
        }
    }
}

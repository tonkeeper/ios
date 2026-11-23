import Foundation
@testable import KeeperCore
import XCTest

final class PerpsSharedReadsTests: XCTestCase {
    func test_overlappingReadsOfOneKey_shareOneRequest() async throws {
        let started = expectation(description: "the first read is in flight")
        let decided = expectation(description: "the second caller has joined or read")
        let reads = PerpsSharedReads<String, Int>(now: Self.signallingClock(onSecondRead: decided))
        let calls = Counter()
        let gate = Gate()
        let read: @Sendable () async throws -> Int = {
            if calls.increment() == 1 { started.fulfill() }
            await gate.wait()
            return 7
        }

        let first = Task { try await reads.value(for: "a", read: read) }
        await fulfillment(of: [started], timeout: 1)
        let second = Task { try await reads.value(for: "a", read: read) }
        await fulfillment(of: [decided], timeout: 1)
        await gate.open()

        let values = try await[first.value, second.value]
        XCTAssertEqual(values, [7, 7])
        XCTAssertEqual(calls.value, 1)
    }

    func test_readsOfDifferentKeys_doNotShare() async throws {
        let started = expectation(description: "both reads are in flight")
        started.expectedFulfillmentCount = 2
        let reads = PerpsSharedReads<String, Int>()
        let gate = Gate()
        let read: @Sendable () async throws -> Int = {
            started.fulfill()
            await gate.wait()
            return 7
        }

        let first = Task { try await reads.value(for: "a", read: read) }
        let second = Task { try await reads.value(for: "b", read: read) }
        await fulfillment(of: [started], timeout: 1)
        await gate.open()

        let values = try await[first.value, second.value]
        XCTAssertEqual(values, [7, 7])
    }

    func test_finishedRead_isNotReusedWithoutAWindow() async throws {
        let reads = PerpsSharedReads<String, Int>()
        let calls = Counter()

        for _ in 0 ..< 2 {
            _ = try await reads.value(for: "a") { calls.increment() }
        }

        XCTAssertEqual(calls.value, 2)
    }

    func test_succeededRead_answersOnlyWithinTheWindow() async throws {
        let clock = TestClock()
        let reads = PerpsSharedReads<String, Int>(reuseWindow: 1, now: { clock.now })
        let calls = Counter()
        let read: @Sendable () async throws -> Int = { calls.increment() }

        let first = try await reads.value(for: "a", read: read)
        clock.advance(0.5)
        let reused = try await reads.value(for: "a", read: read)
        clock.advance(0.5)
        let fresh = try await reads.value(for: "a", read: read)

        XCTAssertEqual([first, reused, fresh], [1, 1, 2])
    }

    func test_afterInvalidate_noEarlierReadAnswers() async throws {
        let started = expectation(description: "the first read is in flight")
        let reads = PerpsSharedReads<String, Int>(reuseWindow: 60)
        let calls = Counter()
        let gate = Gate()
        let read: @Sendable () async throws -> Int = {
            let call = calls.increment()
            if call == 1 {
                started.fulfill()
                await gate.wait()
            }
            return call
        }

        let first = Task { try await reads.value(for: "a", read: read) }
        await fulfillment(of: [started], timeout: 1)
        reads.invalidate()
        let afterInFlight = try await reads.value(for: "a", read: read)
        reads.invalidate()
        let afterSucceeded = try await reads.value(for: "a", read: read)
        await gate.open()

        let firstValue = try await first.value
        XCTAssertEqual([firstValue, afterInFlight, afterSucceeded], [1, 2, 3])
    }

    func test_failedRead_isNotReused() async throws {
        let reads = PerpsSharedReads<String, Int>(reuseWindow: 60)
        let calls = Counter()
        let read: @Sendable () async throws -> Int = {
            let call = calls.increment()
            if call == 1 { throw URLError(.timedOut) }
            return call
        }

        do {
            _ = try await reads.value(for: "a", read: read)
            XCTFail("the first read fails")
        } catch {}
        let value = try await reads.value(for: "a", read: read)

        XCTAssertEqual(value, 2)
    }

    func test_readJoiningOneThatFails_readsOnItsOwn() async throws {
        let started = expectation(description: "the first read is in flight")
        let decided = expectation(description: "the second caller has joined")
        let reads = PerpsSharedReads<String, Int>(now: Self.signallingClock(onSecondRead: decided))
        let calls = Counter()
        let gate = Gate()
        let read: @Sendable () async throws -> Int = {
            let call = calls.increment()
            guard call == 1 else { return call }
            started.fulfill()
            await gate.wait()
            throw URLError(.userAuthenticationRequired)
        }

        let first = Task { try await reads.value(for: "a", read: read) }
        await fulfillment(of: [started], timeout: 1)
        let second = Task { try await reads.value(for: "a", read: read) }
        await fulfillment(of: [decided], timeout: 1)
        await gate.open()

        let firstResult = await first.result
        XCTAssertThrowsError(try firstResult.get())
        let value = try await second.value
        XCTAssertEqual(value, 2)
    }

    /// The clock is read once per call, under the lock that also decides whether the call joins
    /// a read in flight, so its second read means the second caller has made that decision.
    private static func signallingClock(onSecondRead expectation: XCTestExpectation) -> @Sendable () -> Date {
        let reads = Counter()
        return {
            if reads.increment() == 2 { expectation.fulfill() }
            return Date()
        }
    }
}

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

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_700_000_000)

    var now: Date {
        lock.withLock { date }
    }

    func advance(_ seconds: TimeInterval) {
        lock.withLock { date += seconds }
    }
}

private actor Gate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        continuations.forEach { $0.resume() }
        continuations = []
    }
}

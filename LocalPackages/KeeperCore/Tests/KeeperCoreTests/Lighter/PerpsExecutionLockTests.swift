@testable import KeeperCore
import XCTest

final class PerpsExecutionLockTests: XCTestCase {
    private actor Trace {
        private(set) var events = [String]()
        private(set) var concurrent = 0
        private(set) var peak = 0

        func enter(_ tag: String) {
            concurrent += 1
            peak = max(peak, concurrent)
            events.append("+\(tag)")
        }

        func leave(_ tag: String) {
            concurrent -= 1
            events.append("-\(tag)")
        }
    }

    private let keyA = PerpsExecutionLock.Scope(accountIndex: 1, apiKeyIndex: 0)
    private let keyB = PerpsExecutionLock.Scope(accountIndex: 1, apiKeyIndex: 1)
    private let otherAccount = PerpsExecutionLock.Scope(accountIndex: 2, apiKeyIndex: 0)

    func test_sameKeyRunsOneAtATime() async {
        let lock = PerpsExecutionLock()
        let trace = Trace()

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 8 {
                group.addTask { [keyA] in
                    try? await lock.withScope(keyA) {
                        await trace.enter("\(index)")
                        try? await Task.sleep(nanoseconds: 2_000_000)
                        await trace.leave("\(index)")
                    }
                }
            }
        }

        let peak = await trace.peak
        XCTAssertEqual(peak, 1, "two operations must never sign on one api key at the same time")
        let events = await trace.events
        XCTAssertEqual(events.count, 16)
        for pair in stride(from: 0, to: events.count, by: 2) {
            XCTAssertEqual(events[pair].dropFirst(), events[pair + 1].dropFirst(), "sections interleaved")
        }
    }

    func test_differentApiKeysOfOneAccountDoNotBlockEachOther() async {
        let lock = PerpsExecutionLock()
        let started = expectation(description: "both sections entered")
        started.expectedFulfillmentCount = 2
        let release = expectation(description: "release")

        let first = Task { [keyA] in
            try? await lock.withScope(keyA) {
                started.fulfill()
                await fulfillment(of: [release], timeout: 2)
            }
        }
        let second = Task { [keyB] in
            try? await lock.withScope(keyB) {
                started.fulfill()
            }
        }

        await fulfillment(of: [started], timeout: 2)
        release.fulfill()
        _ = await(first.value, second.value)
    }

    func test_differentAccountsDoNotBlockEachOther() async {
        let lock = PerpsExecutionLock()
        let started = expectation(description: "both sections entered")
        started.expectedFulfillmentCount = 2
        let release = expectation(description: "release")

        let first = Task { [keyA] in
            try? await lock.withScope(keyA) {
                started.fulfill()
                await fulfillment(of: [release], timeout: 2)
            }
        }
        let second = Task { [otherAccount] in
            try? await lock.withScope(otherAccount) {
                started.fulfill()
            }
        }

        await fulfillment(of: [started], timeout: 2)
        release.fulfill()
        _ = await(first.value, second.value)
    }

    func test_aThrowingSectionStillReleasesTheKey() async {
        let lock = PerpsExecutionLock()
        struct Boom: Error {}

        do {
            try await lock.withScope(keyA) { throw Boom() }
            XCTFail("expected the section to rethrow")
        } catch {}

        let reacquired = Task { [keyA] in
            try? await lock.withScope(keyA) { true }
        }
        let value = await withTaskGroup(of: Bool?.self) { group in
            group.addTask { await reacquired.value }
            group.addTask {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        XCTAssertEqual(value, true, "a failed submission must not strand the api key")
    }

    func test_canceledWaiterDoesNotEnterAfterTheKeyIsReleased() async {
        let lock = PerpsExecutionLock()
        let entered = expectation(description: "first entered")
        let release = expectation(description: "release")

        let first = Task { [keyA] in
            try? await lock.withScope(keyA) {
                entered.fulfill()
                await fulfillment(of: [release], timeout: 2)
            }
        }
        await fulfillment(of: [entered], timeout: 2)

        let waiter = Task { [keyA] in
            do {
                return try await lock.withScope(keyA) { true }
            } catch {
                return false
            }
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
        waiter.cancel()
        let waiterResult = await waiter.value
        XCTAssertFalse(waiterResult)

        release.fulfill()
        await first.value
        let reacquired = try? await lock.withScope(keyA) { true }
        XCTAssertTrue(reacquired == true)
    }
}

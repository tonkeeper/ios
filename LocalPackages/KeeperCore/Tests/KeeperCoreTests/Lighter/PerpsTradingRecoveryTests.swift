import Foundation
@testable import KeeperCore
import XCTest

final class PerpsTradingRecoveryTests: XCTestCase {
    func testAPassThatLeavesWorkRepeatsWithAGrowingDelayAndStopsOnceTheJournalIsEmpty() async {
        let passes = ScriptedPasses(leavingWork: 2)
        let delays = RecordedDelays()
        let recovery = PerpsTradingRecovery(
            recover: { passes.run() },
            renewAutoClose: { _ in true },
            sleep: { _ = await delays.record($0) }
        )

        recovery.recover()

        await fulfillment(of: [passes.journalEmptied], timeout: 2)
        await fulfillment(of: [passes.extraPass], timeout: 0.3)
        let recorded = await delays.values
        XCTAssertEqual(recorded, [5_000_000_000, 10_000_000_000])
        withExtendedLifetime(recovery) {}
    }

    func testARequestDuringTheBackoffRunsAPassAtOnceAndStartsTheDelayOver() async {
        let passes = ScriptedPasses(leavingWork: 2)
        let delays = RecordedDelays()
        let firstWait = expectation(description: "the first retry is waiting")
        let (neverElapses, elapse) = AsyncStream<Void>.makeStream()
        defer { elapse.finish() }
        let recovery = PerpsTradingRecovery(
            recover: { passes.run() },
            renewAutoClose: { _ in true },
            sleep: { delay in
                guard await delays.record(delay) == 1 else { return }
                firstWait.fulfill()
                for await _ in neverElapses {}
            }
        )
        recovery.recover()
        await fulfillment(of: [firstWait], timeout: 2)

        recovery.recover()

        await fulfillment(of: [passes.journalEmptied], timeout: 2)
        let recorded = await delays.values
        XCTAssertEqual(recorded, [5_000_000_000, 5_000_000_000])
        withExtendedLifetime(recovery) {}
    }

    func testAFailedAutoCloseRenewalRunsAgainOnTheNextResolveAndASentOneHoldsForAnHour() async {
        let start = Date()
        let clock = ScriptedClock([0, 60, 120, 2 * 60 * 60].map { start.addingTimeInterval($0) })
        let failed = expectation(description: "the first renewal ran and sent nothing")
        let retried = expectation(description: "the next resolve ran the renewal again")
        let tooSoon = expectation(description: "a resolve a minute after a sent renewal ran another one")
        tooSoon.isInverted = true
        let anHourLater = expectation(description: "a resolve an hour later ran the renewal")
        let recovery = PerpsTradingRecovery(
            recover: { true },
            renewAutoClose: { marketIds in
                switch marketIds {
                case [1]:
                    failed.fulfill()
                    return false
                case [2]:
                    retried.fulfill()
                case [3]:
                    tooSoon.fulfill()
                default:
                    anHourLater.fulfill()
                }
                return true
            },
            now: { clock.next() }
        )
        var reads = clock.reads.makeAsyncIterator()

        recovery.renewAutoClose(marketIds: [1])
        await fulfillment(of: [failed], timeout: 2)
        recovery.renewAutoClose(marketIds: [2])
        await fulfillment(of: [retried], timeout: 2)
        recovery.renewAutoClose(marketIds: [3])
        for _ in 0 ..< 3 {
            _ = await reads.next()
        }
        recovery.renewAutoClose(marketIds: [4])
        await fulfillment(of: [anHourLater], timeout: 2)
        await fulfillment(of: [tooSoon], timeout: 0.1)
        withExtendedLifetime(recovery) {}
    }

    func testLettingTheOwnerGoCancelsItsPassAndItsRenewal() async {
        let passStarted = expectation(description: "a pass is running")
        let passCancelled = expectation(description: "the pass was cancelled")
        let renewalStarted = expectation(description: "a renewal is running")
        let renewalCancelled = expectation(description: "the renewal was cancelled")
        let (passNeverEnds, endPass) = AsyncStream<Void>.makeStream()
        let (renewalNeverEnds, endRenewal) = AsyncStream<Void>.makeStream()
        defer {
            endPass.finish()
            endRenewal.finish()
        }
        var recovery: PerpsTradingRecovery? = PerpsTradingRecovery(
            recover: {
                passStarted.fulfill()
                for await _ in passNeverEnds {}
                passCancelled.fulfill()
                return false
            },
            renewAutoClose: { _ in
                renewalStarted.fulfill()
                for await _ in renewalNeverEnds {}
                renewalCancelled.fulfill()
                return false
            }
        )
        recovery?.recover()
        recovery?.renewAutoClose(marketIds: [1])
        await fulfillment(of: [passStarted, renewalStarted], timeout: 2)

        recovery = nil

        await fulfillment(of: [passCancelled, renewalCancelled], timeout: 2)
    }
}

private final class ScriptedPasses: @unchecked Sendable {
    let journalEmptied = XCTestExpectation(description: "the pass that emptied the journal ran")
    let extraPass = XCTestExpectation(description: "a pass after the journal emptied")

    private let lock = NSLock()
    private var leavingWork: Int
    private var emptied = false

    init(leavingWork: Int) {
        self.leavingWork = leavingWork
        extraPass.isInverted = true
    }

    func run() -> Bool {
        let (done, extra) = lock.withLock { () -> (Bool, Bool) in
            if emptied { return (true, true) }
            guard leavingWork == 0 else {
                leavingWork -= 1
                return (false, false)
            }
            emptied = true
            return (true, false)
        }
        if extra {
            extraPass.fulfill()
        } else if done {
            journalEmptied.fulfill()
        }
        return done
    }
}

private actor RecordedDelays {
    private(set) var values: [UInt64] = []

    @discardableResult
    func record(_ delay: UInt64) -> Int {
        values.append(delay)
        return values.count
    }
}

private final class ScriptedClock: @unchecked Sendable {
    let reads: AsyncStream<Void>
    private let read: AsyncStream<Void>.Continuation
    private let lock = NSLock()
    private var dates: [Date]

    init(_ dates: [Date]) {
        self.dates = dates
        (reads, read) = AsyncStream<Void>.makeStream()
    }

    func next() -> Date {
        defer { read.yield() }
        return lock.withLock { dates.count > 1 ? dates.removeFirst() : dates[0] }
    }
}

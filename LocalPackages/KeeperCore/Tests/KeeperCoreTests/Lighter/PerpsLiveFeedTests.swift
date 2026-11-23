import Foundation
@testable import KeeperCore
import XCTest

final class PerpsLiveFeedTests: XCTestCase {
    func test_withoutChannel_returnsAfterPollInterval() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let listener = await feed.listen([.account], debounce: 0)

        let polled = await finishes(within: 1) { await listener.next(pollAfter: 0.1) }
        let waited = await finishes(within: 0.2) { await listener.next(pollAfter: 5) }

        XCTAssertTrue(polled)
        XCTAssertFalse(waited)
    }

    func test_liveEvent_wakesMatchingListenersOnly() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let btc = await feed.listen([.market(1)], debounce: 0)
        let eth = await feed.listen([.market(2)], debounce: 0)
        let any = await feed.listen([.anyMarket], debounce: 0)
        source.send(.subscribed(recovered: true))
        source.send(.event(.market(1)))
        await settle()

        let btcWoke = await finishes(within: 0.3) { await btc.next(pollAfter: 10) }
        let anyWoke = await finishes(within: 0.3) { await any.next(pollAfter: 10) }
        let ethWoke = await finishes(within: 0.3) { await eth.next(pollAfter: 10) }

        XCTAssertTrue(btcWoke)
        XCTAssertTrue(anyWoke)
        XCTAssertFalse(ethWoke)
    }

    func test_changesWhileNobodyWaits_areKeptAndCoalesced() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let listener = await feed.listen([.account], debounce: 0)
        source.send(.subscribed(recovered: true))
        source.send(.event(.account))
        source.send(.event(.account))
        await settle()

        let first = await finishes(within: 0.2) { await listener.next(pollAfter: 10) }
        let second = await finishes(within: 0.3) { await listener.next(pollAfter: 10) }

        XCTAssertTrue(first)
        XCTAssertFalse(second)
    }

    func test_unrecoveredSubscription_wakesEveryListener() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let account = await feed.listen([.account], debounce: 0)
        let deposit = await feed.listen([.deposit], debounce: 0)
        source.send(.subscribed(recovered: true))
        source.send(.unsubscribed)
        source.send(.subscribed(recovered: false))
        await settle()

        let accountWoke = await finishes(within: 0.2) { await account.next(pollAfter: 10) }
        let depositWoke = await finishes(within: 0.2) { await deposit.next(pollAfter: 10) }

        XCTAssertTrue(accountWoke)
        XCTAssertTrue(depositWoke)
    }

    func test_recoveredSubscription_wakesNobody() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let listener = await feed.listen([.account], debounce: 0)
        source.send(.subscribed(recovered: true))
        await settle()

        let woke = await finishes(within: 0.3) { await listener.next(pollAfter: 10) }

        XCTAssertFalse(woke)
    }

    func test_liveTimeout_boundsTheWaitOnALiveChannel() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let listener = await feed.listen([.market(1)], debounce: 0)
        source.send(.subscribed(recovered: true))
        await settle()

        let woke = await finishes(within: 1) { await listener.next(pollAfter: 10, liveTimeout: 0.1) }

        XCTAssertTrue(woke)
    }

    func test_droppedChannel_fallsBackToPolling() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let listener = await feed.listen([.account], debounce: 0)
        source.send(.subscribed(recovered: true))
        await settle()
        let whileLive = await finishes(within: 0.3) { await listener.next(pollAfter: 0.1) }

        let waiting = Task { await listener.next(pollAfter: 0.1) }
        await settle()
        source.send(.unsubscribed)
        let afterDrop = await finishes(within: 1) { await waiting.value }

        XCTAssertFalse(whileLive)
        XCTAssertTrue(afterDrop)
    }

    func test_debounce_mergesABurstIntoOneWake() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let listener = await feed.listen([.account, .anyMarket], debounce: 0.1)
        source.send(.subscribed(recovered: true))
        await settle()

        let waiting = Task { await listener.next(pollAfter: 10) }
        source.send(.event(.market(3)))
        source.send(.event(.account))
        source.send(.event(.account))
        let first = await finishes(within: 1) { await waiting.value }
        let second = await finishes(within: 0.3) { await listener.next(pollAfter: 10) }

        XCTAssertTrue(first)
        XCTAssertFalse(second)
    }

    func test_passiveListener_hearsAHeldChannelButNeverHoldsIt() async {
        let source = SignalSource()
        let released = expectation(description: "channel released")
        source.onTerminate = { released.fulfill() }
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let passive = await feed.listen([.deposit], debounce: 0, holdsSubscription: false)
        XCTAssertEqual(source.opened, 0)

        var holder: PerpsLiveListener? = await feed.listen([.account])
        source.send(.subscribed(recovered: true))
        source.send(.event(.deposit))
        await settle()
        let heard = await finishes(within: 0.3) { await passive.next(pollAfter: 10) }
        holder = nil
        await fulfillment(of: [released], timeout: 1)
        let polled = await finishes(within: 1) { await passive.next(pollAfter: 0.1) }

        XCTAssertNil(holder)
        XCTAssertEqual(source.opened, 1)
        XCTAssertTrue(heard)
        XCTAssertTrue(polled)
    }

    func test_waits_keepAChangeThatCameBetweenTwoWaits() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let wait = feed.waits(on: [.deposit])
        await settle()
        XCTAssertEqual(source.opened, 0)
        let holder = await feed.listen([.account])
        source.send(.subscribed(recovered: true))
        source.send(.event(.deposit))
        await settle()

        let first = await finishes(within: 1) { await wait(10_000_000_000) }
        let second = await finishes(within: 0.3) { await wait(10_000_000_000) }

        withExtendedLifetime(holder) {}
        XCTAssertTrue(first)
        XCTAssertFalse(second)
    }

    func test_waits_tellAChangeFromATimeout() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let holder = await feed.listen([.account])
        let wait = feed.waits(on: [.deposit])
        await settle()

        let timedOut = await wait(100_000_000)
        source.send(.subscribed(recovered: true))
        source.send(.event(.deposit))
        let changed = await wait(10_000_000_000)

        withExtendedLifetime(holder) {}
        XCTAssertFalse(timedOut)
        XCTAssertTrue(changed)
    }

    func test_aNewWaitReplacesOneStillWaiting() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let listener = await feed.listen([.account], debounce: 0)
        let first = Task { await listener.next(pollAfter: 10) }
        await settle()

        let secondReturned = await finishes(within: 0.3) { await listener.next(pollAfter: 10) }
        let firstChanged = await first.value

        XCTAssertFalse(secondReturned)
        XCTAssertFalse(firstChanged)
    }

    func test_aHolderReopensSignalsThatEnded() async {
        let source = SignalSource()
        let feed = PerpsLiveFeed(signals: { source.stream() })
        let first = await feed.listen([.account])
        source.finishAll()
        await settle()

        let second = await feed.listen([.account], debounce: 0)
        source.send(.subscribed(recovered: true))
        source.send(.event(.account))
        await settle()
        let woke = await finishes(within: 0.3) { await second.next(pollAfter: 10) }

        withExtendedLifetime(first) {}
        XCTAssertEqual(source.opened, 2)
        XCTAssertTrue(woke)
    }

    func test_channelIsHeldWhileListenersLive() async {
        let source = SignalSource()
        let released = expectation(description: "channel released")
        source.onTerminate = { released.fulfill() }
        let feed = PerpsLiveFeed(signals: { source.stream() })
        var first: PerpsLiveListener? = await feed.listen([.account])
        var second: PerpsLiveListener? = await feed.listen([.deposit])
        XCTAssertEqual(source.opened, 1)

        first = nil
        await settle()
        XCTAssertEqual(source.terminated, 0)
        second = nil

        await fulfillment(of: [released], timeout: 1)
        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(source.opened, 1)
    }
}

private extension PerpsLiveFeedTests {
    func settle() async {
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    func finishes(within seconds: TimeInterval, _ operation: @escaping @Sendable () async -> Void) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await operation()
                return true
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }
}

private final class SignalSource: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [AsyncStream<PerpsRealtimeSignal>.Continuation]()
    private var openedCount = 0
    private var terminatedCount = 0
    var onTerminate: (() -> Void)?

    var opened: Int {
        lock.withLock { openedCount }
    }

    var terminated: Int {
        lock.withLock { terminatedCount }
    }

    func stream() -> AsyncStream<PerpsRealtimeSignal> {
        let (stream, continuation) = AsyncStream<PerpsRealtimeSignal>.makeStream()
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            self.lock.withLock { self.terminatedCount += 1 }
            self.onTerminate?()
        }
        lock.withLock {
            continuations.append(continuation)
            openedCount += 1
        }
        return stream
    }

    func send(_ signal: PerpsRealtimeSignal) {
        lock.withLock { continuations }.forEach { $0.yield(signal) }
    }

    func finishAll() {
        lock.withLock { continuations }.forEach { $0.finish() }
    }
}

import Foundation
@testable import KeeperCore
import XCTest

final class PerpsPositionsControllerTests: XCTestCase {
    func testFlushAppliesThePendingTickBeforeItReturns() async {
        let applied = AppliedTicks()
        let (starts, started) = AsyncStream<WatchCallbacks>.makeStream()
        let controller = PerpsPositionsController(
            makeWatch: { _, update, interrupt in
                started.yield(WatchCallbacks(update: update, interrupt: interrupt))
                return PerpsPositionsWatch {}
            },
            onUpdate: { applied.record($0) },
            onInterrupted: {}
        )
        var watches = starts.makeAsyncIterator()
        controller.start()
        controller.subscribe(cadence: .live)
        guard let watch = await watches.next() else { return XCTFail("missing watch") }

        watch.update(.positions([]))
        await controller.flush()

        XCTAssertEqual(applied.count, 1)
        await controller.stop()
    }

    func testFlushWithoutAWatchReturnsInsteadOfHanging() async {
        let controller = PerpsPositionsController(
            makeWatch: { _, _, _ in PerpsPositionsWatch {} },
            onUpdate: { _ in XCTFail("nothing to apply") },
            onInterrupted: {}
        )

        await controller.flush()
        controller.start()
        controller.subscribe(cadence: .live)
        await controller.stop()
        await controller.flush()
    }

    func testCancelledStreamRejectsLateUpdatesAndInterruptions() async {
        let (starts, started) = AsyncStream<WatchCallbacks>.makeStream()
        let received = expectation(description: "only the replacement tick lands")
        received.assertForOverFulfill = true
        let interruptions = WatchLog()
        let controller = PerpsPositionsController(
            makeWatch: { _, update, interrupt in
                started.yield(WatchCallbacks(update: update, interrupt: interrupt))
                return PerpsPositionsWatch { update(.portfolio(PerpsAccountSnapshot(availableBalance: "0"))); interrupt() }
            },
            onUpdate: { tick in
                guard case .positions = tick else { return XCTFail("stale portfolio tick delivered") }
                received.fulfill()
            },
            onInterrupted: { interruptions.record("interrupted") }
        )
        var watches = starts.makeAsyncIterator()
        controller.start()
        controller.subscribe(cadence: .ambient)
        guard let first = await watches.next() else { return XCTFail("missing watch") }
        controller.subscribe(cadence: .live)
        guard let second = await watches.next() else { return XCTFail("missing replacement") }

        second.update(.positions([]))
        first.update(.positions([]))
        first.interrupt()
        await controller.flush()

        await fulfillment(of: [received], timeout: 1)
        XCTAssertEqual(interruptions.entries, [], "the replaced watch's consumer ended before the replacement started")
        await controller.stop()
    }

    func testBackgroundDropsTheWatchAndKeepsTheSubscriptionsForTheForeground() async {
        let watches = WatchLog()
        let controller = PerpsPositionsController(
            makeWatch: { cadence, _, _ in
                watches.record("start \(cadence)")
                return PerpsPositionsWatch { watches.record("cancel \(cadence)") }
            },
            onUpdate: { _ in },
            onInterrupted: {}
        )
        controller.start()
        controller.subscribe(cadence: .ambient)
        controller.setForeground(false)
        controller.subscribe(cadence: .live)
        await controller.flush()
        XCTAssertEqual(watches.entries, ["start ambient", "cancel ambient"])

        controller.setForeground(true)
        await controller.flush()
        XCTAssertEqual(watches.entries.suffix(1), ["start live"])

        controller.unsubscribe(cadence: .live)
        await controller.flush()
        XCTAssertEqual(watches.entries.suffix(2), ["cancel live", "start ambient"])
        await controller.stop()
    }

    func testAWatchThatIgnoresCadenceIsSharedByEveryScreen() async {
        let watches = WatchLog()
        let controller = PerpsPositionsController(
            makeWatch: { cadence, _, _ in
                watches.record("start \(cadence)")
                return PerpsPositionsWatch(followsCadence: false) { watches.record("cancel \(cadence)") }
            },
            onUpdate: { _ in },
            onInterrupted: {}
        )
        controller.start()
        controller.subscribe(cadence: .ambient)
        controller.subscribe(cadence: .live)
        controller.unsubscribe(cadence: .live)
        await controller.flush()

        XCTAssertEqual(watches.entries, ["start ambient"])
        await controller.stop()
    }
}

private final class WatchLog: @unchecked Sendable {
    private let lock = NSLock()
    private var log = [String]()

    var entries: [String] {
        lock.withLock { log }
    }

    func record(_ entry: String) {
        lock.withLock { log.append(entry) }
    }
}

private struct WatchCallbacks: Sendable {
    let update: @Sendable (PerpsAccountTick) -> Void
    let interrupt: @Sendable () -> Void
}

private final class AppliedTicks: @unchecked Sendable {
    private let lock = NSLock()
    private var ticks = [PerpsAccountTick]()

    var count: Int {
        lock.withLock { ticks.count }
    }

    func record(_ tick: PerpsAccountTick) {
        lock.withLock { ticks.append(tick) }
    }
}

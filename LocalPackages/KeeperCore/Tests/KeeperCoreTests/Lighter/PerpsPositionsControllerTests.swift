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
            onInterrupted: {},
            onStop: {}
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
            onInterrupted: {},
            onStop: {}
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
        let interrupted = expectation(description: "old interruption ignored")
        interrupted.isInverted = true
        let controller = PerpsPositionsController(
            makeWatch: { _, update, interrupt in
                started.yield(WatchCallbacks(update: update, interrupt: interrupt))
                return PerpsPositionsWatch { update(.orders([])); interrupt() }
            },
            onUpdate: { tick in
                guard case .positions = tick else { return XCTFail("stale order tick delivered") }
                received.fulfill()
            },
            onInterrupted: { interrupted.fulfill() },
            onStop: {}
        )
        var watches = starts.makeAsyncIterator()
        controller.start()
        controller.subscribe(cadence: .ambient)
        guard let first = await watches.next() else { return XCTFail("missing watch") }
        controller.subscribe(cadence: .live)
        guard let second = await watches.next() else { return XCTFail("missing replacement") }

        second.update(.positions([]))
        first.update(.orders([]))
        first.interrupt()
        await controller.flush()

        await fulfillment(of: [received, interrupted], timeout: 0.1)
        await controller.stop()
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

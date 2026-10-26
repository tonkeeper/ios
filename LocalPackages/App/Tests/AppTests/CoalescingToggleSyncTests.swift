@testable import App
import XCTest

@MainActor
final class CoalescingToggleSyncTests: XCTestCase {
    func test_toggle_burstWhileInFlight_sendsOnlyTheNewestChange() async {
        let harness = Harness()
        harness.toggle(true, current: false)
        await harness.didStartSync()
        harness.toggle(false)
        harness.toggle(true)
        let last = harness.toggle(false)

        harness.release()
        await last.value

        XCTAssertEqual(harness.synced, [true, false])
        XCTAssertEqual(harness.shown, [true, false, true, false])
    }

    func test_toggle_burstEndingAtAcceptedValue_sendsNothingMore() async {
        let harness = Harness()
        harness.toggle(true, current: false)
        await harness.didStartSync()
        harness.toggle(false)
        let last = harness.toggle(true)

        harness.release()
        await last.value

        XCTAssertEqual(harness.synced, [true])
    }

    func test_toggle_rejected_rollsBackToAcceptedValue() async {
        let harness = Harness(accepts: false)
        let task = harness.toggle(true, current: false)
        harness.release()
        await task.value

        XCTAssertEqual(harness.shown, [true, false])
    }

    func test_toggle_rejectedAfterUserMovedAway_doesNotRollBack() async {
        let harness = Harness(accepts: false)
        harness.toggle(true, current: false)
        await harness.didStartSync()
        let last = harness.toggle(false)

        harness.release()
        await last.value

        XCTAssertEqual(harness.synced, [true])
        XCTAssertEqual(harness.shown, [true, false])
    }

    func test_toggle_afterIdle_startsFromCurrentValue() async {
        let harness = Harness()
        let first = harness.toggle(true, current: false)
        harness.release()
        await first.value

        let second = harness.toggle(true, current: false)
        await second.value

        XCTAssertEqual(harness.synced, [true, true])
    }

    func test_toggle_duringPendingRollback_stillSyncsNewIntent() async {
        let sync = CoalescingToggleSync<String>()
        let rollback = ApplyGate()
        var synced = [Bool]()
        var shown = [Bool]()
        let apply: @MainActor (Bool) async -> Void = { value in
            shown.append(value)
            if !value { await rollback.block() }
        }
        let send: @MainActor (Bool, Bool) async -> Bool = { value, _ in
            synced.append(value)
            return synced.count > 1
        }

        sync.toggle(true, key: "app", currentIsOn: false, apply: apply, sync: send)
        await rollback.didStart()
        let last = sync.toggle(true, key: "app", currentIsOn: true, apply: apply, sync: send)
        rollback.release()
        await last.value

        XCTAssertEqual(synced, [true, true])
        XCTAssertEqual(shown, [true, false, true])
    }

    func test_toggle_waitsForStoreWriteBeforeSync() async {
        let sync = CoalescingToggleSync<String>()
        let write = ApplyGate()
        var synced = [Bool]()

        let task = sync.toggle(
            true,
            key: "app",
            currentIsOn: false,
            apply: { _ in await write.block() },
            sync: { value, _ in
                synced.append(value)
                return true
            }
        )
        await write.didStart()
        XCTAssertTrue(synced.isEmpty)
        write.release()
        await task.value

        XCTAssertEqual(synced, [true])
    }

    func test_rejected_reconcilesAfterRollbackWrite() async {
        let sync = CoalescingToggleSync<String>()
        let rollback = ApplyGate()
        var persisted = false
        var reconciled = [Bool]()

        let task = sync.toggle(
            true,
            key: "app",
            currentIsOn: false,
            apply: { value in
                if !value { await rollback.block() }
                persisted = value
            },
            sync: { _, _ in false },
            onRejected: { reconciled.append(persisted) }
        )
        await rollback.didStart()
        XCTAssertTrue(reconciled.isEmpty)
        rollback.release()
        await task.value

        XCTAssertEqual(reconciled, [false])
    }
}

// MARK: -

@MainActor
private final class Harness {
    private let sync = CoalescingToggleSync<String>()
    private let accepts: Bool
    private var isReleased = false
    private var releaseWaiters = [CheckedContinuation<Void, Never>]()
    private var syncStartWaiters = [CheckedContinuation<Void, Never>]()
    private(set) var shown = [Bool]()
    private(set) var synced = [Bool]()

    init(accepts: Bool = true) {
        self.accepts = accepts
    }

    @discardableResult
    func toggle(_ isOn: Bool, current: Bool? = nil) -> Task<Void, Never> {
        sync.toggle(
            isOn,
            key: "app",
            currentIsOn: current ?? shown.last ?? false,
            apply: { [weak self] in self?.shown.append($0) },
            sync: { [weak self] value, _ in
                guard let self else { return false }
                synced.append(value)
                syncStartWaiters.forEach { $0.resume() }
                syncStartWaiters = []
                if !isReleased {
                    await withCheckedContinuation { self.releaseWaiters.append($0) }
                }
                return accepts
            }
        )
    }

    func didStartSync() async {
        guard synced.isEmpty else { return }
        await withCheckedContinuation { self.syncStartWaiters.append($0) }
    }

    func release() {
        isReleased = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters = []
    }
}

@MainActor
private final class ApplyGate {
    private var started = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func block() async {
        started = true
        startWaiter?.resume()
        startWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
    }

    func didStart() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

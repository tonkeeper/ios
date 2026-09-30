@testable import App
import Foundation
import XCTest

/// Cancelling a request does not undo it once it has left the device, so opposite mutations of the
/// same wallet must never overlap: whichever finished last would decide the backend state.
final class SerialRequestQueueTests: XCTestCase {
    func test_enqueue_doesNotStartAPassBeforeThePreviousOneFinished() async {
        let queue = SerialRequestQueue<String>()
        let recorder = Recorder()
        let gate = AsyncGate()

        queue.enqueue("a") {
            recorder.append("first.start")
            await gate.wait()
            recorder.append("first.end")
        }
        await recorder.didAppend("first.start")
        // The compensating pass is in flight; the user toggles back before it returns.
        let second = queue.enqueue("a") {
            recorder.append("second.start")
            recorder.append("second.end")
        }
        XCTAssertEqual(recorder.entries, ["first.start"])

        gate.open()
        await second.value

        XCTAssertEqual(
            recorder.entries,
            ["first.start", "first.end", "second.start", "second.end"]
        )
    }

    /// Queued passes can carry different failure policies even when they will read the same state,
    /// so a background pass must not discard the user pass that owns rollback.
    func test_enqueue_keepsEveryQueuedPass() async {
        let queue = SerialRequestQueue<String>()
        let recorder = Recorder()
        let gate = AsyncGate()

        queue.enqueue("a") {
            recorder.append("first")
            await gate.wait()
        }
        await recorder.didAppend("first")
        queue.enqueue("a") { recorder.append("second") }
        let third = queue.enqueue("a") { recorder.append("third") }

        gate.open()
        await third.value

        XCTAssertEqual(recorder.entries, ["first", "second", "third"])
    }

    func test_enqueue_keepsKeysIndependent() async {
        let queue = SerialRequestQueue<String>()
        let recorder = Recorder()
        let gate = AsyncGate()

        queue.enqueue("a") {
            recorder.append("a")
            await gate.wait()
        }
        await recorder.didAppend("a")
        let other = queue.enqueue("b") { recorder.append("b") }
        await other.value

        XCTAssertEqual(recorder.entries, ["a", "b"])
        gate.open()
    }
}

final class OptimisticToggleSyncTests: XCTestCase {
    func test_failedSync_restoresValueReadWhenPassStarted() async {
        let state = LockedBool(true)

        let didSync = await OptimisticToggleSync.run(
            isOn: false,
            currentIsOn: { state.value },
            setIsOn: { state.value = $0 },
            sync: { false }
        )

        XCTAssertFalse(didSync)
        XCTAssertTrue(state.value)
    }

    func test_failedQueuedIntent_doesNotInvertEarlierRollback() async {
        let queue = SerialRequestQueue<String>()
        let state = LockedBool(true)
        let firstSyncStarted = AsyncGate()
        let finishFirstSync = AsyncGate()

        queue.enqueue("dapp") {
            _ = await OptimisticToggleSync.run(
                isOn: false,
                currentIsOn: { state.value },
                setIsOn: { state.value = $0 },
                sync: {
                    firstSyncStarted.open()
                    await finishFirstSync.wait()
                    return false
                }
            )
        }
        await firstSyncStarted.wait()
        let second = queue.enqueue("dapp") {
            _ = await OptimisticToggleSync.run(
                isOn: true,
                currentIsOn: { state.value },
                setIsOn: { state.value = $0 },
                sync: { false }
            )
        }

        finishFirstSync.open()
        await second.value

        XCTAssertTrue(state.value)
    }
}

// MARK: -

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded = [String]()
    private var waiters = [String: AsyncGate]()

    var entries: [String] {
        lock.withLock { recorded }
    }

    func append(_ entry: String) {
        let gate: AsyncGate? = lock.withLock {
            recorded.append(entry)
            return waiters[entry]
        }
        gate?.open()
    }

    /// Waits until `entry` has been recorded, so a test can act while a pass is mid-flight.
    func didAppend(_ entry: String) async {
        let gate: AsyncGate = lock.withLock {
            if let existing = waiters[entry] {
                return existing
            }
            let gate = AsyncGate()
            waiters[entry] = gate
            if recorded.contains(entry) {
                gate.open()
            }
            return gate
        }
        await gate.wait()
    }
}

private final class AsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [UnsafeContinuation<Void, Never>]()
    private var isOpen = false

    func wait() async {
        await withUnsafeContinuation { continuation in
            lock.lock()
            guard !isOpen else {
                lock.unlock()
                continuation.resume()
                return
            }
            continuations.append(continuation)
            lock.unlock()
        }
    }

    func open() {
        lock.lock()
        isOpen = true
        let pending = continuations
        continuations = []
        lock.unlock()
        pending.forEach { $0.resume() }
    }
}

private final class LockedBool: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Bool

    init(_ value: Bool) {
        storedValue = value
    }

    var value: Bool {
        get {
            lock.withLock { storedValue }
        }
        set {
            lock.withLock { storedValue = newValue }
        }
    }
}

@testable import App
import Foundation
import KeeperCore
import XCTest

final class MultichainStartupControllerTests: XCTestCase {
    func test_bindingsReconcile_runsOnceWhenItSucceeds() async {
        let syncController = FakeWalletSyncController(result: true)
        let controller = makeController(syncController: syncController)

        await controller.startBindingsReconcile()
        await controller.startBindingsReconcile()

        XCTAssertEqual(syncController.reconcileCount, 1)
    }

    /// A pass that never reached the backend has bound nothing, so the next trigger — foreground —
    /// has to be able to run it again.
    func test_bindingsReconcile_repeatsUntilItSucceeds() async {
        let syncController = FakeWalletSyncController(result: false)
        let controller = makeController(syncController: syncController)

        await controller.startBindingsReconcile()
        await controller.startBindingsReconcile()
        syncController.result = true
        await controller.startBindingsReconcile()
        await controller.startBindingsReconcile()

        XCTAssertEqual(syncController.reconcileCount, 3)
    }

    func test_bindingsReconcile_doesNotStartASecondPassWhileOneIsRunning() async {
        let syncController = FakeWalletSyncController(result: true)
        syncController.gate = AsyncGate()
        let controller = makeController(syncController: syncController)

        async let first: Void = controller.startBindingsReconcile()
        await syncController.didStart.wait()
        await controller.startBindingsReconcile()
        syncController.gate?.open()
        await first

        XCTAssertEqual(syncController.reconcileCount, 1)
    }

    /// A trigger that arrives mid-pass cannot simply be dropped: the pass in flight can still fail,
    /// and the foreground event that raised it will not come again until the next foreground.
    func test_bindingsReconcile_runsTheTriggerRaisedWhileAFailingPassWasInFlight() async {
        let syncController = FakeWalletSyncController(result: false)
        syncController.gate = AsyncGate()
        let controller = makeController(syncController: syncController)

        async let first: Void = controller.startBindingsReconcile()
        await syncController.didStart.wait()
        await controller.startBindingsReconcile()
        syncController.gate?.open()
        await first

        XCTAssertEqual(syncController.reconcileCount, 2)
    }

    func test_bindingsReconcile_doesNothingWhenTheFeatureIsOff() async {
        let syncController = FakeWalletSyncController(result: false)
        let controller = makeController(syncController: syncController, isEnabled: false)

        await controller.startBindingsReconcile()
        await controller.startBindingsReconcile()

        XCTAssertEqual(syncController.reconcileCount, 0)
    }

    private func makeController(
        syncController: MultichainWalletSyncController,
        isEnabled: Bool = true
    ) -> MultichainStartupController {
        MultichainStartupController(
            isEnabled: isEnabled,
            authService: FakeMultichainAuthService(),
            walletSyncController: syncController
        )
    }
}

// MARK: -

private final class FakeWalletSyncController: MultichainWalletSyncController, @unchecked Sendable {
    var result: Bool
    var gate: AsyncGate?
    let didStart = AsyncGate()
    private(set) var reconcileCount = 0

    init(result: Bool) {
        self.result = result
    }

    var needsStartupSync: Bool {
        false
    }

    func needsStartupAppKeyWarm() async -> Bool {
        false
    }

    func syncPendingWallets(passcode _: String) async {}

    func warmMissingAppKeys(passcode _: String) async {}

    func reconcileBindings() async -> Bool {
        reconcileCount += 1
        didStart.open()
        if let gate {
            await gate.wait()
        }
        return result
    }
}

private struct FakeMultichainAuthService: MultichainAuthService {
    func deviceId() async throws(MultichainServiceError) -> String {
        "device-1"
    }

    func isDeviceKnown() async -> Bool {
        true
    }

    func deviceBindings(walletIds _: [String]) async throws(MultichainServiceError) -> DeviceBindings {
        DeviceBindings(known: [], unknown: [], extra: [])
    }

    func registerWallets(
        walletId _: String,
        makeBatch _: @escaping (String) async throws(MultichainServiceError) -> MultichainWalletRegisterBatch
    ) async throws(MultichainServiceError) -> [MultichainWalletRegisterResult] {
        []
    }

    func unregisterWallets(walletIds _: [String]) async throws(MultichainServiceError) {}
    func enqueueUnregisterWallets(walletIds _: [String]) {}
    func flushPendingUnregisters() async {}
    func subscribePush(
        pushToken _: String,
        locale _: String?,
        walletIds _: [String]
    ) async throws(MultichainServiceError) {}
    func unsubscribePush() async throws(MultichainServiceError) {}
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

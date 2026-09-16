@testable import KeeperCore
import XCTest

/// A rotation that lands inside the reconcile it triggered is the case the controller exists for:
/// that reconcile describes the previous device, so dropping it would leave the wallets marked
/// bound to a device that holds no bindings.
final class MultichainDeviceChangeControllerTests: XCTestCase {
    func test_handle_reconcilesOnceAndNotifiesWhenNothingRotates() async {
        let context = Context()

        await context.controller.handle()

        XCTAssertEqual(context.reconcileCount, 1)
        XCTAssertEqual(context.notifyCount, 1)
    }

    func test_handle_repeatsTheReconcileForARotationThatLandedDuringIt() async {
        let context = Context()
        context.rotateDuringPasses = [1]

        await context.controller.handle()

        XCTAssertEqual(context.reconcileCount, 2)
        // The push subscription resolves the current device id itself, so the coalesced rotations
        // need exactly one notification — after the last pass.
        XCTAssertEqual(context.notifyCount, 1)
    }

    func test_handle_dropsTheNestedCallInsteadOfReconcilingConcurrently() async {
        let context = Context()
        context.rotateDuringPasses = [1]

        await context.controller.handle()

        // The rotation raised during pass 1 returned immediately rather than starting its own
        // reconcile, so the passes never overlap.
        XCTAssertEqual(context.maxConcurrentReconciles, 1)
        XCTAssertEqual(context.nestedHandleCount, 1)
    }

    func test_handle_stopsRepeatingAtTheBound() async {
        let context = Context()
        // Every pass rotates the device again: without a bound this would never settle.
        context.rotateDuringPasses = Set(1 ... 32)

        await context.controller.handle()

        XCTAssertEqual(context.reconcileCount, MultichainDeviceChangeController.maxReconciles)
        XCTAssertEqual(context.notifyCount, 1)
    }

    func test_handle_isReusableAfterItSettled() async {
        let context = Context()

        await context.controller.handle()
        await context.controller.handle()

        XCTAssertEqual(context.reconcileCount, 2)
        XCTAssertEqual(context.notifyCount, 2)
    }

    /// The notification resolves the current device id by authenticating, so it can rotate the
    /// device itself — and it runs while `isHandling` is still set, which used to turn that
    /// rotation into a pending change nobody picked up.
    func test_handle_reconcilesAgainForARotationRaisedByTheNotification() async {
        let context = Context()
        context.rotateDuringNotifications = [1]

        await context.controller.handle()

        XCTAssertEqual(context.reconcileCount, 2)
        XCTAssertEqual(context.notifyCount, 2)
    }

    func test_handle_stopsRepeatingWhenEveryNotificationRotatesAgain() async {
        let context = Context()
        context.rotateDuringNotifications = Set(1 ... 32)

        await context.controller.handle()

        XCTAssertEqual(context.reconcileCount, MultichainDeviceChangeController.maxReconciles)
    }

    /// The bound leaves `hasPendingChange` set; the next rotation must still get a full pass.
    func test_handle_afterTheBoundWasHitStillReconciles() async {
        let context = Context()
        context.rotateDuringPasses = Set(1 ... MultichainDeviceChangeController.maxReconciles)

        await context.controller.handle()
        let reconcilesAfterBound = context.reconcileCount
        context.rotateDuringPasses = []
        await context.controller.handle()

        XCTAssertEqual(context.reconcileCount, reconcilesAfterBound + 1)
    }
}

// MARK: -

private final class Context: @unchecked Sendable {
    /// 1-based pass numbers during which a device rotation is raised.
    var rotateDuringPasses = Set<Int>()
    /// 1-based notification numbers during which a device rotation is raised.
    var rotateDuringNotifications = Set<Int>()
    private(set) var reconcileCount = 0
    private(set) var notifyCount = 0
    private(set) var nestedHandleCount = 0
    private(set) var maxConcurrentReconciles = 0

    private var activeReconciles = 0

    private(set) lazy var controller = MultichainDeviceChangeController(
        reconcileBindings: { [self] in await reconcile() },
        didChangeDevice: { [self] in await notify() }
    )

    private func notify() async {
        notifyCount += 1
        let notification = notifyCount

        guard rotateDuringNotifications.contains(notification) else { return }
        // Resolving the device id for the push subscription re-registered it, so the notification
        // reenters the controller while this `handle()` is still running.
        nestedHandleCount += 1
        await controller.handle()
    }

    private func reconcile() async {
        reconcileCount += 1
        let pass = reconcileCount
        activeReconciles += 1
        maxConcurrentReconciles = max(maxConcurrentReconciles, activeReconciles)
        defer { activeReconciles -= 1 }

        guard rotateDuringPasses.contains(pass) else { return }
        // What `DeviceAuthService` does when the session it just authenticated with re-registered:
        // the notification reenters the controller while this reconcile is still running.
        nestedHandleCount += 1
        await controller.handle()
    }
}

@testable import App
import XCTest

final class ScannerCameraLifecycleTests: XCTestCase {
    func testPermissionGrantAndForegroundCallbacksConfigureTheCameraOnlyOnce() {
        var setup = ScannerCameraSetupState()
        XCTAssertTrue(setup.beginConfiguration())
        XCTAssertFalse(setup.beginConfiguration())
        setup.didConfigure()
        XCTAssertFalse(setup.beginConfiguration())
    }

    func testOnlyAConfigurationFailureAllowsAnotherSetupAttempt() {
        var setup = ScannerCameraSetupState()
        XCTAssertTrue(setup.beginConfiguration())
        setup.didFailConfiguration()
        XCTAssertTrue(setup.beginConfiguration())
        setup.didConfigure()
        setup.didFailConfiguration()
        XCTAssertFalse(setup.beginConfiguration())
    }

    func testRejectedDeliveryAllowsAForegroundRestart() throws {
        var lifecycle = ScannerCaptureLifecycle()
        lifecycle.appear()
        let run = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertTrue(lifecycle.consumeScan(run: run))
        lifecycle.rejectScan(run: run)
        let retry = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertNotEqual(retry, run)
        XCTAssertTrue(lifecycle.consumeScan(run: retry))
        XCTAssertNil(lifecycle.beginRun(isRunning: false))
    }

    func testAnOldRejectedDeliveryCannotRearmANewerDeliveredScan() throws {
        var lifecycle = ScannerCaptureLifecycle()
        lifecycle.appear()
        let old = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertTrue(lifecycle.consumeScan(run: old))
        lifecycle.disappear()
        lifecycle.appear()
        let current = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertTrue(lifecycle.consumeScan(run: current))
        lifecycle.rejectScan(run: old)
        XCTAssertNil(lifecycle.beginRun(isRunning: false))
    }

    func testForegroundingAfterDeliveryDoesNotStartAnotherCaptureRun() throws {
        var lifecycle = ScannerCaptureLifecycle()
        lifecycle.appear()
        let run = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertTrue(lifecycle.consumeScan(run: run))
        XCTAssertNil(lifecycle.beginRun(isRunning: false))
        XCTAssertFalse(lifecycle.consumeScan(run: run))
    }

    func testANewAppearanceAllowsScanningAgainButRejectsThePreviousRun() throws {
        var lifecycle = ScannerCaptureLifecycle()
        XCTAssertNil(lifecycle.beginRun(isRunning: false))
        lifecycle.appear()
        let oldRun = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertTrue(lifecycle.consumeScan(run: oldRun))
        lifecycle.disappear()
        XCTAssertNil(lifecycle.beginRun(isRunning: false))
        lifecycle.appear()
        let newRun = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertNotEqual(newRun, oldRun)
        XCTAssertFalse(lifecycle.consumeScan(run: oldRun))
        XCTAssertTrue(lifecycle.consumeScan(run: newRun))
    }

    func testRejectedURKeepsTheLiveCameraRunAvailableForTheNextCode() throws {
        var lifecycle = ScannerCaptureLifecycle()
        lifecycle.appear()
        let run = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertTrue(lifecycle.consumeScan(run: run))

        XCTAssertFalse(lifecycle.completeScan(run: run, accepted: false))
        XCTAssertEqual(lifecycle.beginRun(isRunning: true), run)
        XCTAssertTrue(lifecycle.consumeScan(run: run))
        XCTAssertTrue(lifecycle.completeScan(run: run, accepted: true))
        XCTAssertNil(lifecycle.beginRun(isRunning: true))
        XCTAssertFalse(lifecycle.consumeScan(run: run))
    }

    func testAnOldAcceptedDeliveryCannotStopANewerCameraRun() throws {
        var lifecycle = ScannerCaptureLifecycle()
        lifecycle.appear()
        let old = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertTrue(lifecycle.consumeScan(run: old))
        lifecycle.disappear()
        lifecycle.appear()
        let current = try XCTUnwrap(lifecycle.beginRun(isRunning: false))

        XCTAssertFalse(lifecycle.completeScan(run: old, accepted: true))
        XCTAssertTrue(lifecycle.consumeScan(run: current))
        XCTAssertTrue(lifecycle.completeScan(run: current, accepted: true))
    }

    func testRepeatedAppearancePreservesAnAcceptedDeliveryClaim() throws {
        var lifecycle = ScannerCaptureLifecycle()
        lifecycle.appear()
        let run = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertTrue(lifecycle.consumeScan(run: run))

        lifecycle.appear()

        XCTAssertNil(lifecycle.beginRun(isRunning: true))
        XCTAssertTrue(lifecycle.completeScan(run: run, accepted: true))
        XCTAssertFalse(lifecycle.consumeScan(run: run))
    }

    func testRepeatedAppearancePreservesARejectedDeliveryUntilItCanRearm() throws {
        var lifecycle = ScannerCaptureLifecycle()
        lifecycle.appear()
        let run = try XCTUnwrap(lifecycle.beginRun(isRunning: false))
        XCTAssertTrue(lifecycle.consumeScan(run: run))

        lifecycle.appear()

        XCTAssertNil(lifecycle.beginRun(isRunning: true))
        XCTAssertFalse(lifecycle.completeScan(run: run, accepted: false))
        XCTAssertEqual(lifecycle.beginRun(isRunning: true), run)
        XCTAssertTrue(lifecycle.consumeScan(run: run))
    }

    func testQueuedDeliveryOnlyBelongsToTheAppearanceWhereItWasRead() {
        var visibility = ScannerViewVisibility()
        let first = visibility.appear()
        XCTAssertTrue(visibility.allowsDelivery(appearance: first))
        XCTAssertEqual(visibility.appear(), first)
        XCTAssertTrue(visibility.allowsDelivery(appearance: first))

        visibility.disappear()
        XCTAssertFalse(visibility.allowsDelivery(appearance: first))
        let next = visibility.appear()

        XCTAssertNotEqual(first, next)
        XCTAssertFalse(visibility.allowsDelivery(appearance: first))
        XCTAssertTrue(visibility.allowsDelivery(appearance: next))
    }

    func testReappearanceStartsANewRunEvenIfTheCaptureSessionIsAlreadyRunning() throws {
        var lifecycle = ScannerCaptureLifecycle()
        lifecycle.appear()
        let old = try XCTUnwrap(lifecycle.beginRun(isRunning: true))
        XCTAssertTrue(lifecycle.consumeScan(run: old))
        lifecycle.disappear()
        lifecycle.appear()

        let current = try XCTUnwrap(lifecycle.beginRun(isRunning: true))

        XCTAssertNotEqual(old, current)
        XCTAssertFalse(lifecycle.completeScan(run: old, accepted: true))
        XCTAssertTrue(lifecycle.consumeScan(run: current))
        XCTAssertTrue(lifecycle.completeScan(run: current, accepted: true))
    }
}

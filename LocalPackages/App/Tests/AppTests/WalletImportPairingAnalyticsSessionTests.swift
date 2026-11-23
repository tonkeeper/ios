@testable import App
import TKCore
import XCTest

@MainActor
final class WalletImportPairingAnalyticsSessionTests: XCTestCase {
    func testOnlyTheFirstActionIsReportedAcrossScannerRestartsAndSignerRoundTrip() {
        let recorder = Recorder()
        let session = makeSession(recorder)
        session.start()
        session.start()
        session.action(.signerAppOpened)
        session.cameraStateChanged(.running)
        session.cameraStateChanged(.running)
        session.exit()

        XCTAssertEqual(recorder.names, ["wallet_import_started", "wallet_import_pairing_action", "wallet_import_pairing_exit"])
        XCTAssertEqual(recorder.calls[1].args["pairing_action"] as? String, "signer_app_opened")
        XCTAssertEqual(recorder.calls.last?.args["pairing_last_step"] as? String, "action")
    }

    func testPermissionDeniedBeforeAnActionIsReportedOnlyOnFinalExit() {
        let recorder = Recorder()
        let session = makeSession(recorder)
        session.start()
        session.cameraStateChanged(.permissionDenied)
        XCTAssertEqual(recorder.names, ["wallet_import_started"])

        session.exit()
        session.exit()

        XCTAssertEqual(recorder.names, ["wallet_import_started", "wallet_import_pairing_exit"])
        XCTAssertEqual(recorder.calls.last?.args["pairing_last_step"] as? String, "none")
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "camera_permission_denied")
    }

    func testPermissionRecoveryClearsTheBlockerAndKeepsTheFurthestStepAfterBackNavigation() {
        let recorder = Recorder()
        let session = makeSession(recorder)
        session.start()
        session.cameraStateChanged(.permissionDenied)
        session.cameraStateChanged(.running)
        session.advance(to: .connected)
        session.cameraStateChanged(.running)
        session.advance(to: .action)
        session.exit()

        XCTAssertEqual(recorder.calls.last?.args["pairing_last_step"] as? String, "connected")
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "back")
    }

    func testRecoveryOfOneBlockerDoesNotClearAnUnrelatedImportFailure() {
        let recorder = Recorder()
        let session = makeSession(recorder)
        session.start()
        session.setBlocked(.importError)
        session.cameraStateChanged(.permissionDenied)
        session.cameraStateChanged(.running)
        session.exit()

        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "error")
    }

    func testCameraSetupFailureIsClearedOnlyAfterTheCameraActuallyRuns() {
        let recorder = Recorder()
        let session = makeSession(recorder)
        session.start()
        session.cameraStateChanged(.failed)
        session.exit()
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "error")
        XCTAssertEqual(recorder.calls.last?.args["pairing_last_step"] as? String, "none")

        let recovered = makeSession(recorder, source: .keystone)
        recovered.start()
        recovered.cameraStateChanged(.failed)
        recovered.cameraStateChanged(.running)
        recovered.exit()
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "back")
        XCTAssertEqual(recorder.calls.last?.args["wallet_source"] as? String, "keystone")
    }

    func testTheLatestUnresolvedBlockerWinsAndResolvedErrorsDoNotMaskBack() {
        let recorder = Recorder()
        let session = makeSession(recorder)
        session.start()
        session.setBlocked(.bluetoothOff)
        session.setBlocked(.connectionError)
        session.setBlocked(.connectionError, isBlocked: false)
        session.exit()
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "bluetooth_off")

        let recovered = makeSession(recorder)
        recovered.start()
        recovered.setBlocked(.bluetoothPermissionDenied)
        recovered.setBlocked(.bluetoothPermissionDenied, isBlocked: false)
        recovered.exit()
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "back")
    }

    func testTransientBluetoothStatesDoNotClearDenialButPoweredOnDoes() {
        let recorder = Recorder()
        let denied = makeSession(recorder, source: .ledger)
        denied.start()
        denied.bluetoothStateChanged(.unauthorized)
        denied.bluetoothStateChanged(.resetting)
        denied.exit()
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "bluetooth_permission_denied")

        let recovered = makeSession(recorder, source: .ledger)
        recovered.start()
        recovered.bluetoothStateChanged(.poweredOff)
        recovered.bluetoothStateChanged(.poweredOn)
        recovered.exit()
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "back")
    }

    func testLedgerDevicesAreDeduplicatedForTheEntireSessionButNotForANewSession() {
        let recorder = Recorder()
        let session = makeSession(recorder, source: .ledger, mode: .multi)
        let first = UUID()
        let second = UUID()
        session.start()
        session.action(.deviceSearchStarted)
        session.deviceFound(id: first, model: .nanoX)
        session.advance(to: .connected)
        session.deviceFound(id: first, model: .nanoX)
        session.deviceFound(id: second, model: nil)
        session.advance(to: .appOpened)
        session.advance(to: .accountsView)
        session.advance(to: .connected)
        session.exit()

        let found = recorder.calls.filter { $0.name == "wallet_import_ledger_device_found" }
        XCTAssertEqual(found.count, 2)
        XCTAssertEqual(found.first?.args["ledger_transport"] as? String, "bluetooth")
        XCTAssertNil(found.last?.args["ledger_model"])
        XCTAssertFalse(found.contains { $0.args.values.contains { String(describing: $0) == first.uuidString } })
        XCTAssertEqual(recorder.calls.last?.args["pairing_last_step"] as? String, "accounts_view")

        let reopened = makeSession(recorder, source: .ledger, mode: .multi)
        reopened.start()
        reopened.deviceFound(id: first, model: .nanoX)
        XCTAssertEqual(recorder.calls.filter { $0.name == "wallet_import_ledger_device_found" }.count, 3)
    }

    func testSuccessEndsTheSessionBeforeDismissalAndIgnoresLateCallbacks() {
        let recorder = Recorder()
        let session = makeSession(recorder)
        session.start()
        session.success()
        session.exit()
        session.success()
        session.cameraStateChanged(.running)
        session.deviceFound(id: UUID(), model: nil)
        session.start()

        XCTAssertFalse(session.isActive)
        XCTAssertEqual(recorder.names, ["wallet_import_started", "wallet_import_success"])
        XCTAssertEqual(recorder.calls.last?.args["pairing_entry"] as? String, "menu")
    }

    func testDismissalIgnoresLateSuccessAndOtherCallbacks() {
        let recorder = Recorder()
        let session = makeSession(recorder)
        session.start()
        session.exit(reason: .other)
        session.success()
        session.action(.cameraOpened)
        session.exit()

        XCTAssertEqual(recorder.names, ["wallet_import_started", "wallet_import_pairing_exit"])
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "other")
    }

    func testDismissalDuringPersistenceDefersTheExitAndPreservesTheStoredWalletSuccess() {
        for source in [WalletSource.signer, .keystone, .ledger] {
            let recorder = Recorder()
            let session = makeSession(recorder, source: source)
            session.start()
            XCTAssertTrue(session.beginImport())
            XCTAssertFalse(session.beginImport())
            XCTAssertFalse(session.exit())
            XCTAssertFalse(session.isActive)
            session.cameraStateChanged(.running)
            XCTAssertEqual(recorder.names, ["wallet_import_started"])

            session.success()
            session.exit()
            XCTAssertEqual(recorder.names, ["wallet_import_started", "wallet_import_success"])
        }
    }

    func testPersistenceFailureAfterDismissalReportsTheErrorBeforeTheSingleExit() {
        let recorder = Recorder()
        let session = makeSession(recorder, source: .ledger, mode: .multi)
        session.start()
        XCTAssertTrue(session.beginImport())
        XCTAssertFalse(session.exit())
        XCTAssertFalse(session.exit())
        XCTAssertTrue(session.importFailed(error: TestError.failed, ledgerModel: .nanoX))
        XCTAssertFalse(session.importFailed(error: TestError.failed))
        XCTAssertEqual(recorder.names, ["wallet_import_started", "wallet_import_error", "wallet_import_pairing_exit"])
        XCTAssertEqual(recorder.calls[1].args["wallet_mode"] as? String, "multi")
        XCTAssertEqual(recorder.calls[1].args["ledger_model"] as? String, "nano_x")
        XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "error")
    }

    func testVisiblePersistenceFailureAllowsRetryAndDirectEntriesNeverEmitAnExit() {
        let recorder = Recorder()
        let session = makeSession(recorder, entry: .deeplink, hasPairingScreen: false)
        session.start()
        XCTAssertTrue(session.beginImport())
        XCTAssertFalse(session.importFailed(error: TestError.failed))
        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.beginImport())
        XCTAssertFalse(session.exit())
        session.success()
        XCTAssertEqual(recorder.names, ["wallet_import_started", "wallet_import_error", "wallet_import_success"])
    }

    func testBluetoothStateRemainsTheCauseOfItsConsequentConnectionFailure() {
        for bluetoothFirst in [true, false] {
            let recorder = Recorder()
            let session = makeSession(recorder, source: .ledger)
            session.start()
            if !bluetoothFirst { session.setBlocked(.connectionError) }
            session.bluetoothStateChanged(.poweredOff)
            if bluetoothFirst { session.setBlocked(.connectionError) }
            session.exit()
            XCTAssertEqual(recorder.calls.last?.args["pairing_exit_reason"] as? String, "bluetooth_off")
        }
    }

    private enum TestError: Error { case failed }

    func testDirectSignerEntriesCarryTheirEntryWithoutSyntheticPairingStepsOrExit() {
        for entry in [PairingEntry.deeplink, .appQrScanner] {
            let recorder = Recorder()
            let session = makeSession(recorder, entry: entry, hasPairingScreen: false)
            session.start()
            session.action(.cameraOpened)
            session.success()
            session.exit()
            XCTAssertEqual(recorder.names, ["wallet_import_started", "wallet_import_success"])
            XCTAssertTrue(recorder.calls.allSatisfy { $0.args["pairing_entry"] as? String == entry.rawValue })

            let cancelled = makeSession(recorder, entry: entry, hasPairingScreen: false)
            cancelled.start()
            cancelled.exit()
            XCTAssertEqual(recorder.names.last, "wallet_import_started")
            XCTAssertFalse(cancelled.isActive)
        }
    }

    func testEveryLedgerEventKeepsTheSameModeAndOrigin() {
        for mode in [WalletMode.single, .multi] {
            for from in [AddWalletSource.onboarding, .main] {
                let recorder = Recorder()
                let session = makeSession(recorder, source: .ledger, mode: mode, from: from)
                session.start()
                session.action(.deviceSearchStarted)
                session.deviceFound(id: UUID(), model: .nanoX)
                session.success(ledgerModel: .nanoX)

                for event in recorder.calls {
                    XCTAssertEqual(event.args["wallet_mode"] as? String, mode.rawValue)
                    XCTAssertEqual(event.args["wallet_source"] as? String, "ledger")
                    XCTAssertEqual(event.args["from"] as? String, from.rawValue)
                }
                XCTAssertEqual(recorder.calls.last?.args["ledger_model"] as? String, "nano_x")
            }
        }
    }

    private func makeSession(
        _ recorder: Recorder,
        source: WalletSource = .signer,
        mode: WalletMode = .single,
        from: AddWalletSource = .onboarding,
        entry: PairingEntry = .menu,
        hasPairingScreen: Bool = true
    ) -> WalletImportPairingAnalyticsSession {
        let assembly = CoreAssembly()
        let provider = AnalyticsProvider(
            analyticsServices: [recorder], uniqueIdProvider: assembly.uniqueIdProvider,
            appInfoProvider: assembly.appInfoProvider, keysCountryCodeProvider: assembly.keysCountryCodeProvider
        )
        return WalletImportPairingAnalyticsSession(
            analyticsProvider: provider, walletMode: mode, walletSource: source, from: from,
            entry: entry, hasPairingScreen: hasPairingScreen
        )
    }
}

private final class Recorder: AnalyticsService {
    private(set) var calls: [(name: String, args: [String: Any])] = []
    var names: [String] {
        calls.map(\.name)
    }

    func logEvent(name: String, args: [String: Any]) {
        calls.append((name, args))
    }
}

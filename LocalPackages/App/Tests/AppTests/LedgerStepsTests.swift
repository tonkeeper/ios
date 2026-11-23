@testable import App
@testable import KeeperCore
import LedgerKit
import TKLocalize
import TonSwift
import TonTransport
import XCTest

@MainActor
final class LedgerStepsTests: XCTestCase {
    func testRemovingTheLedgerContentFinishesOnceAsCancelled() {
        var results: [Result<Void, Error>] = []
        let viewModel = LedgerStepsViewModel(
            steps: LedgerSteps<Void>(stages: [.init(app: .ton, prompt: nil)]) { _ in },
            peripheralID: UUID(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.finish() } },
                scan: { AsyncStream { $0.finish() } },
                connect: { _ in OpenTonApp().link }
            )
        )
        viewModel.didFinish = { results.append($0) }
        var controller: LedgerConfirmViewController? = LedgerConfirmViewController(viewModel: viewModel)
        let controllerWasReleased = { [weak controller] in controller == nil }

        controller = nil
        viewModel.stopTasks()

        XCTAssertTrue(controllerWasReleased())
        XCTAssertEqual(results.count, 1)
        XCTAssertThrowsError(try results.first?.get()) { XCTAssertTrue($0 is CancellationError) }
    }

    func testStagesOnlyMoveForward() {
        let phases: [LedgerSession.Phase] = [.connecting, .openingApp(.ton), .running(.ton), .connecting, .openingApp(.ethereum), .openingApp(.ton)]

        let progress = phases.reduce(LedgerStepsProgress()) { $0.reporting($1, apps: [.ton, .ethereum]) }

        XCTAssertEqual(progress, LedgerStepsProgress(stage: 1, phase: .openingApp(.ton), hasConnected: true))
    }

    func testAStageIsSkippedOnceTheWorkGoesOnWithoutItsApp() {
        let apps: [LedgerApp] = [.ethereum, .tron, .ton]
        let notOpened: [LedgerSession.Phase] = [.openingApp(.ethereum), .notOpened(.ethereum, isMissing: true), .openingApp(.tron), .notOpened(.tron, isMissing: false)]

        let refused = notOpened.reduce(LedgerStepsProgress()) { $0.reporting($1, apps: apps) }
        let wentOn = [LedgerSession.Phase.openingApp(.ton)].reduce(refused) { $0.reporting($1, apps: apps) }

        XCTAssertEqual(refused.skip(at: 0), .notInstalled)
        XCTAssertNil(refused.skip(at: 1), "Until the work goes on, the app may be one it cannot do without")
        XCTAssertEqual(wentOn.skip(at: 1), .declined)
    }

    func testAStageTheUserSkipsIsLeftBehindAtOnce() throws {
        let apps: [LedgerApp] = [.ethereum, .tron, .ton]
        let afterEthereum = LedgerStepsProgress(stage: 0, phase: .running(.ethereum), hasConnected: true)

        let choosing = try XCTUnwrap(afterEthereum.choosing(.tron, apps: apps))
        let skipped = choosing.chose(false)

        XCTAssertEqual(choosing.stage, 1)
        XCTAssertTrue(choosing.isChoosing)
        XCTAssertEqual(skipped.stage, 2)
        XCTAssertFalse(skipped.isChoosing)
        XCTAssertEqual(skipped.skip(at: 1), .skipped)
        XCTAssertEqual(choosing.chose(true), LedgerStepsProgress(stage: 1, phase: .running(.ethereum), hasConnected: true))
    }

    func testAnAppLeftBehindDoesNotMarkTheStageThatRuns() {
        let apps: [LedgerApp] = [.ethereum, .tron, .ton]
        let stopped = LedgerStepsProgress(stage: 0, phase: .openingApp(.ethereum), hasConnected: true).chose(false)

        let late = stopped.reporting(.notOpened(.ethereum, isMissing: false), apps: apps)

        XCTAssertEqual(late, stopped)
        XCTAssertEqual(late.skip(at: 0), .skipped)
    }

    func testAnEarlierPhaseLeavesTheChoiceOn() throws {
        let apps: [LedgerApp] = [.ethereum, .tron, .ton]
        let choosing = try XCTUnwrap(LedgerStepsProgress().choosing(.ethereum, apps: apps))

        let late = [LedgerSession.Phase.connecting, .connected].reduce(choosing) { $0.reporting($1, apps: apps) }

        XCTAssertEqual(late, LedgerStepsProgress(stage: 0, phase: .connected, hasConnected: true, isChoosing: true))
    }

    func testTheStepsConnectBeforeTheChoiceAndASkippedAppIsNeverOpened() async {
        let finished = expectation(description: "finished")
        let device = OpenTonApp()
        var connectedWhenAsked: Bool?
        var result: Result<[String], Error>?
        let viewModel = LedgerStepsViewModel(
            steps: LedgerSteps<[String]>(stages: [.init(app: .ethereum, prompt: nil, adds: "Ethereum"), .init(app: .ton, prompt: nil)]) { session, choice in
                let ethereum = try await session.optionalKeys(on: .ethereum, choice: choice) { session in
                    try await session.run(on: .ethereum) { _ in "ethereum" }
                }.value
                let ton = try await session.run(on: .ton) { _ in "ton" }
                return [ethereum, ton].compactMap { $0 }
            },
            peripheralID: UUID(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.finish() } },
                connect: { _ in device.link }
            )
        )
        viewModel.didUpdateModel = { model in
            guard model.confirmButton != nil, connectedWhenAsked == nil else { return }
            connectedWhenAsked = model.contentViewModel.stepModels.first?.state == .done
            model.cancelButton.action?()
        }
        viewModel.didFinish = {
            result = $0
            finished.fulfill()
        }

        viewModel.viewDidLoad()
        await fulfillment(of: [finished], timeout: 1)
        viewModel.stopTasks()

        XCTAssertEqual(connectedWhenAsked, true)
        XCTAssertEqual(try result?.get(), ["ton"])
        let sent = await device.sent
        XCTAssertEqual(sent, ["b001000000"], "The Ledger is only asked which app is open")
    }

    func testNetworkFlowsMakeOnlySelectedAppsSkippable() {
        let pairing = LedgerSteps<LedgerDiscovery>.discovery([0], apps: [.ethereum, .solana], choosesApps: true)
        let subsequentPairingRead = LedgerSteps<LedgerDiscovery>.discovery([1], apps: [.ethereum, .solana], choosesApps: false)
        let adding = LedgerSteps<LedgerNetworkRead<LedgerAppKeys>>.addNetworks(
            [.eth, .bsc, .tron],
            tonPublicKey: TonSwift.PublicKey(data: Data(repeating: 0, count: 32)),
            account: 0
        )
        let migrating = LedgerSteps<LedgerNetworkRead<[AccountPath: LedgerMultichainAccount]>>.multichainAccounts(
            [],
            chains: [.ton, .sol, .btc]
        )

        XCTAssertEqual(pairing.stages.map(\.adds), ["Ethereum", "Solana", nil] as [String?])
        XCTAssertEqual(pairing.stages.map(\.startsAutomatically), [true, true, false])
        XCTAssertEqual(subsequentPairingRead.stages.map(\.adds), [nil, nil, nil] as [String?])
        XCTAssertEqual(adding.stages.map(\.adds), [nil, "Ethereum", "Tron"] as [String?])
        XCTAssertEqual(adding.stages.map(\.startsAutomatically), [false, true, true])
        XCTAssertEqual(migrating.stages.map(\.adds), [nil, "Solana", "Bitcoin"] as [String?])
        XCTAssertEqual(migrating.stages.map(\.startsAutomatically), [false, true, true])
    }

    func testAnAutomaticallyStartedAppCanBeSkippedWithoutConfirmation() async throws {
        let finished = expectation(description: "finished")
        let device = TonAppThatWillNotQuit()
        var model: LedgerConfirmView.Model?
        var result: Result<[String], Error>?
        var showedConfirm = false
        let viewModel = LedgerStepsViewModel(
            steps: LedgerSteps<[String]>(
                stages: [
                    .init(app: .ethereum, prompt: nil, adds: "Ethereum", startsAutomatically: true),
                    .init(app: .ton, prompt: nil),
                ]
            ) { session, choice in
                let ethereum = try await session.optionalKeys(on: .ethereum, choice: choice) { session in
                    try await session.run(on: .ethereum) { _ in "ethereum" }
                }.value
                let ton = try await session.run(on: .ton) { _ in "ton" }
                return [ethereum, ton].compactMap { $0 }
            },
            peripheralID: UUID(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.finish() } },
                connect: { _ in device.link }
            )
        )
        viewModel.didUpdateModel = { updated in
            model = updated
            showedConfirm = showedConfirm || updated.confirmButton != nil
        }
        viewModel.didFinish = {
            result = $0
            finished.fulfill()
        }

        viewModel.viewDidLoad()
        await device.waitUntilQuitting()

        XCTAssertFalse(showedConfirm)
        XCTAssertEqual(model?.cancelButton.content.title, .plainString(TKLocales.LedgerSteps.skip))
        model?.cancelButton.action?()
        await fulfillment(of: [finished], timeout: 1)
        viewModel.stopTasks()

        XCTAssertEqual(try result?.get(), ["ton"])
    }

    func testCancelStopsTheConfirmedAppAloneAndTheStepsGoOn() async throws {
        let finished = expectation(description: "finished")
        let device = TonAppThatWillNotQuit()
        var model: LedgerConfirmView.Model?
        var result: Result<[String], Error>?
        let viewModel = LedgerStepsViewModel(
            steps: LedgerSteps<[String]>(stages: [.init(app: .ethereum, prompt: nil, adds: "Ethereum"), .init(app: .ton, prompt: nil)]) { session, choice in
                let ethereum = try await session.optionalKeys(on: .ethereum, choice: choice) { session in
                    try await session.run(on: .ethereum) { _ in "ethereum" }
                }.value
                let ton = try await session.run(on: .ton) { _ in "ton" }
                return [ethereum, ton].compactMap { $0 }
            },
            peripheralID: UUID(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.finish() } },
                connect: { _ in device.link }
            )
        )
        viewModel.didUpdateModel = { updated in
            model = updated
            updated.confirmButton?.action?()
        }
        viewModel.didFinish = {
            result = $0
            finished.fulfill()
        }

        viewModel.viewDidLoad()
        await device.waitUntilQuitting()
        model?.cancelButton.action?()
        await fulfillment(of: [finished], timeout: 1)
        viewModel.stopTasks()

        XCTAssertEqual(try result?.get(), ["ton"])
        let ethereum = try XCTUnwrap(model?.contentViewModel.stepModels[1])
        XCTAssertEqual(ethereum.state, .skipped)
        XCTAssertEqual(ethereum.caption, TKLocales.LedgerSteps.appSkipped)
    }

    func testAMissingAppIsNamedAndEndsTheSteps() async {
        let finished = expectation(description: "finished")
        var toasts: [String] = []
        var result: Result<Void, Error>?
        let viewModel = LedgerStepsViewModel(
            steps: LedgerSteps<Void>(stages: [.init(app: .ethereum, prompt: nil)]) { session in
                try await session.run(on: .ethereum) { _ in }
            },
            peripheralID: UUID(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.finish() } },
                connect: { _ in LedgerLink(exchange: dashboardWithoutApps, disconnected: AsyncStream { _ in }, close: {}) }
            )
        )
        viewModel.showToast = { toasts.append($0.title) }
        viewModel.didFinish = {
            result = $0
            finished.fulfill()
        }

        viewModel.viewDidLoad()
        await fulfillment(of: [finished], timeout: 1)
        viewModel.stopTasks()

        XCTAssertEqual(toasts, [TKLocales.LedgerSteps.appMissing("Ethereum")])
        XCTAssertThrowsError(try result?.get())
    }

    func testAddressVerificationReconnectsAfterTheDisplayReplyIsLost() async throws {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
        let device = ReconnectingAddressDevice(publicKey: publicKey.data)
        let steps = try XCTUnwrap(LedgerSteps<Void>.verifyAddress(
            MultichainWalletAddress(chain: .ton, address: "ton-address", type: .tonV4R2),
            tonPublicKey: publicKey,
            account: 0
        ))
        let session = LedgerSession(transport: device.transport, peripheralID: UUID(), pollInterval: 0) { _ in }

        try await steps.run(session, LedgerAppChoice(isConfirmed: { _ in true }, stopped: { _ in }))
        await session.close()

        let connections = await device.connections
        let displays = await device.displays
        XCTAssertEqual(connections, 2)
        XCTAssertEqual(displays, 2)
    }

    func testConnectionFailuresShowRecoveryInstructions() async {
        let connect = TKLocales.LedgerConnect.Steps.BluetoothConnect.description
        let cases: [(LedgerTransportError, String)] = [
            (.timeout, connect),
            (.disconnected, connect),
            (.peripheralNotFound, connect),
            (.bluetoothUnavailable, TKLocales.Bluetooth.PoweredOffAlert.message),
            (.bluetoothUnsupported, TKLocales.Errors.unknown),
        ]
        for (error, message) in cases {
            let finished = expectation(description: "connection failure handled")
            var toasts: [String] = []
            let viewModel = LedgerStepsViewModel(
                steps: LedgerSteps<Void>(stages: [.init(app: .ton, prompt: nil)]) { _ in throw error },
                peripheralID: UUID(),
                transport: LedgerTransport(
                    bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                    scan: { AsyncStream { $0.finish() } },
                    connect: { _ in OpenTonApp().link }
                )
            )
            viewModel.showToast = { toasts.append($0.title) }
            viewModel.didFinish = { _ in finished.fulfill() }

            viewModel.viewDidLoad()
            await fulfillment(of: [finished], timeout: 1)
            viewModel.stopTasks()

            XCTAssertEqual(toasts, [message])
        }
    }

    func testStepsWhoseSheetGoesAwayWhileTheyRunEndAsCancelled() async {
        let connected = expectation(description: "connected")
        connected.assertForOverFulfill = false
        var results: [Result<Void, Error>] = []
        let viewModel = LedgerStepsViewModel(
            steps: LedgerSteps<Void>(stages: [.init(app: .ton, prompt: nil)]) { _ in
                try await Task.sleep(nanoseconds: 60_000_000_000)
            },
            peripheralID: UUID(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.finish() } },
                connect: { _ in OpenTonApp().link }
            )
        )
        viewModel.didUpdateModel = { model in
            if model.contentViewModel.stepModels.first?.state == .done {
                connected.fulfill()
            }
        }
        viewModel.didFinish = { results.append($0) }

        viewModel.viewDidLoad()
        await fulfillment(of: [connected], timeout: 1)
        viewModel.stopTasks()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(results.count, 1)
        XCTAssertThrowsError(try results.first?.get()) { XCTAssertTrue($0 is CancellationError) }
    }
}

/// A Ledger with the TON app open that answers the app query alone.
private actor OpenTonApp {
    private(set) var sent: [String] = []

    nonisolated var link: LedgerLink {
        LedgerLink(exchange: { await self.reply(to: $0) }, disconnected: AsyncStream { _ in }, close: {})
    }

    private func reply(to apdu: Data) -> Data {
        sent.append(apdu.map { String(format: "%02x", $0) }.joined())
        guard apdu.starts(with: [0xB0, 0x01]) else {
            return Data([0x6D, 0x00])
        }
        return Data([0x01, 0x03]) + Data("TON".utf8) + Data([0x05]) + Data("2.7.0".utf8) + Data([0x90, 0x00])
    }
}

/// A Ledger with the TON app open that never quits it, as when a prompt waits on the device: the quit lasts until the
/// exchange is cancelled.
private actor TonAppThatWillNotQuit {
    private var isQuitting = false
    private var quitWaiters: [CheckedContinuation<Void, Never>] = []

    nonisolated var link: LedgerLink {
        LedgerLink(exchange: { try await self.reply(to: $0) }, disconnected: AsyncStream { _ in }, close: {})
    }

    func waitUntilQuitting() async {
        guard !isQuitting else {
            return
        }
        await withCheckedContinuation { quitWaiters.append($0) }
    }

    private func reply(to apdu: Data) async throws -> Data {
        if apdu.starts(with: [0xB0, 0xA7]) {
            isQuitting = true
            quitWaiters.forEach { $0.resume() }
            quitWaiters = []
            try await Task.sleep(nanoseconds: 60_000_000_000)
        }
        guard apdu.starts(with: [0xB0, 0x01]) else {
            return Data([0x6D, 0x00])
        }
        return Data([0x01, 0x03]) + Data("TON".utf8) + Data([0x05]) + Data("2.7.0".utf8) + Data([0x90, 0x00])
    }
}

/// Answers the app query from the dashboard and refuses to open any app as not installed.
@Sendable
private func dashboardWithoutApps(_ apdu: Data) -> Data {
    guard apdu.starts(with: [0xB0, 0x01]) else {
        return Data([0x68, 0x07])
    }
    return Data([0x01, 0x05]) + Data("BOLOS".utf8) + Data([0x05]) + Data("1.0.0".utf8) + Data([0x90, 0x00])
}

private actor ReconnectingAddressDevice {
    private let publicKey: Data
    private(set) var connections = 0
    private(set) var displays = 0

    init(publicKey: Data) {
        self.publicKey = publicKey
    }

    nonisolated var transport: LedgerTransport {
        LedgerTransport(
            bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
            scan: { AsyncStream { $0.finish() } },
            connect: { _ in await self.connect() }
        )
    }

    private func connect() -> LedgerLink {
        connections += 1
        return LedgerLink(exchange: { try await self.reply(to: $0) }, disconnected: AsyncStream { $0.finish() }, close: {})
    }

    private func reply(to apdu: Data) throws -> Data {
        if apdu.starts(with: [0xB0, 0x01]) {
            return Data([0x01, 0x03]) + Data("TON".utf8) + Data([0x05]) + Data("2.7.0".utf8) + Data([0x90, 0x00])
        }
        displays += 1
        if displays == 1 {
            throw LedgerTransportError.timeout
        }
        return publicKey + Data([0x90, 0x00])
    }
}

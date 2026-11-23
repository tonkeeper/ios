@testable import App
import CoreBluetooth
import LedgerKit
import TKCore
import TKTestSupport
import TKUIKit
import TonTransport
import XCTest

@MainActor
final class LedgerConnectViewModelTests: XCTestCase {
    func testDiscoveryResumesAfterBluetoothIsToggledWithADeviceAlreadySelected() async {
        let states = AsyncStream.makeStream(of: CBManagerState.self)
        let requests = AsyncStream.makeStream(of: AsyncStream<LedgerPeripheral>.Continuation.self)
        let firstScan = expectation(description: "first scan")
        let resumedScan = expectation(description: "resumed scan")
        let firstSelected = expectation(description: "first Ledger selected")
        firstSelected.assertForOverFulfill = false
        let poweredOff = expectation(description: "Bluetooth off")
        let secondFound = expectation(description: "second Ledger found after recovery")
        let first = LedgerPeripheral(id: UUID(), name: "Nano X", device: LedgerDevice.bluetoothDevices[0])
        let second = LedgerPeripheral(id: UUID(), name: "Flex", device: LedgerDevice.bluetoothDevices[1])
        var scans: [AsyncStream<LedgerPeripheral>.Continuation] = []
        let collecting = Task { @MainActor in
            for await scan in requests.stream {
                scans.append(scan)
                if scans.count == 1 { firstScan.fulfill() }
                if scans.count == 2 { resumedScan.fulfill() }
            }
        }
        let viewModel = LedgerConnectViewModelImplementation(
            urlOpener: NoURLOpener(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { states.stream },
                scan: { AsyncStream { requests.continuation.yield($0) } },
                connect: { _ in throw LedgerTransportError.pairingRemoved }
            ),
            readsAccounts: true
        )
        defer {
            viewModel.stopTasks()
            collecting.cancel()
            requests.continuation.finish()
            states.continuation.finish()
            scans.forEach { $0.finish() }
        }
        viewModel.didShowPairingRemovedAlert = { _ in firstSelected.fulfill() }
        viewModel.didShowTurnOnBluetoothAlert = { poweredOff.fulfill() }
        viewModel.didFindDevice = { if $0.id == second.id { secondFound.fulfill() } }
        viewModel.viewDidLoad()
        states.continuation.yield(.poweredOn)
        await fulfillment(of: [firstScan], timeout: 5)
        scans.first?.yield(first)
        await fulfillment(of: [firstSelected], timeout: 5)
        states.continuation.yield(.poweredOff)
        await fulfillment(of: [poweredOff], timeout: 5)
        states.continuation.yield(.poweredOn)
        await fulfillment(of: [resumedScan], timeout: 5)
        scans.last?.yield(second)
        await fulfillment(of: [secondFound], timeout: 5)
        XCTAssertEqual(scans.count, 2)
    }

    func testBluetoothUnavailableDoesNotMaskTheTransportExitReasonWithAGenericError() async {
        let reported = expectation(description: "transport unavailable")
        var failures: [Bool] = []
        let viewModel = LedgerConnectViewModelImplementation(
            urlOpener: NoURLOpener(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.yield(LedgerPeripheral(id: UUID(), name: "Nano X", device: LedgerDevice.bluetoothDevices[0])) } },
                connect: { _ in throw LedgerTransportError.bluetoothUnavailable }
            ),
            readsAccounts: true,
            sleep: { _ in throw CancellationError() }
        )
        viewModel.didUpdateConnectionError = {
            failures.append($0)
            reported.fulfill()
        }
        viewModel.viewDidLoad()
        await fulfillment(of: [reported], timeout: 5)
        await viewModel.sessionTask?.value
        viewModel.stopTasks()
        XCTAssertEqual(failures, [false])
    }

    func testSearchWaitsForBluetoothAndDiscoveryPrecedesAutomaticConnection() async {
        let states = AsyncStream.makeStream(of: CBManagerState.self)
        let poweredOff = expectation(description: "Bluetooth off")
        let denied = expectation(description: "Bluetooth denied")
        let connected = expectation(description: "connection attempted")
        let peripheral = LedgerPeripheral(id: UUID(), name: "Nano X", device: LedgerDevice.bluetoothDevices[0])
        var events: [String] = []
        let viewModel = LedgerConnectViewModelImplementation(
            urlOpener: NoURLOpener(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { states.stream },
                scan: { AsyncStream { $0.yield(peripheral); $0.yield(peripheral) } },
                connect: { _ in throw LedgerTransportError.pairingRemoved }
            ),
            readsAccounts: true
        )
        viewModel.didShowTurnOnBluetoothAlert = { poweredOff.fulfill() }
        viewModel.didShowBluetoothAuthorisationAlert = { denied.fulfill() }
        viewModel.didStartSearch = { events.append("search") }
        viewModel.didFindDevice = { device in
            XCTAssertEqual(device.id, peripheral.id)
            events.append("found")
        }
        viewModel.didShowPairingRemovedAlert = { _ in
            events.append("connect")
            connected.fulfill()
        }

        viewModel.viewDidLoad()
        states.continuation.yield(.poweredOff)
        await fulfillment(of: [poweredOff], timeout: 5)
        XCTAssertTrue(events.isEmpty)
        states.continuation.yield(.unauthorized)
        await fulfillment(of: [denied], timeout: 5)
        XCTAssertTrue(events.isEmpty)
        states.continuation.yield(.poweredOn)
        await fulfillment(of: [connected], timeout: 5)
        viewModel.stopTasks()
        states.continuation.finish()

        XCTAssertEqual(events, ["search", "found", "connect"])
    }

    func testRemovedPairingWaitsForTheUserInsteadOfRetrying() async {
        let attempts = Attempts()
        let alert = expectation(description: "pairing removed alert")
        alert.assertForOverFulfill = false
        var reconnectDelays: [UInt64] = []
        let viewModel = LedgerConnectViewModelImplementation(
            urlOpener: NoURLOpener(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.yield(LedgerPeripheral(id: UUID(), name: "Nano X", device: LedgerDevice.bluetoothDevices[0])) } },
                connect: { id in
                    await attempts.record(id)
                    throw LedgerTransportError.pairingRemoved
                }
            ),
            readsAccounts: true,
            sleep: { reconnectDelays.append($0) }
        )
        viewModel.didUpdateModel = { $0.devices.first?.tapClosure?() }
        viewModel.didShowPairingRemovedAlert = { _ in alert.fulfill() }

        viewModel.viewDidLoad()
        await fulfillment(of: [alert], timeout: 5)
        await viewModel.sessionTask?.value
        viewModel.stopTasks()

        XCTAssertEqual(reconnectDelays, [], "a removed pairing waits for the user instead of a retry")
        let count = await attempts.ids.count
        XCTAssertEqual(count, 1)
    }

    func testTheFirstLedgerFoundIsConnectedUntilTheUserPicksAnother() async {
        let first = LedgerPeripheral(id: UUID(), name: "Nano X 1A2B", device: LedgerDevice.bluetoothDevices[0])
        let second = LedgerPeripheral(id: UUID(), name: "Flex 3C4D", device: LedgerDevice.bluetoothDevices[1])
        let attempts = Attempts()
        let listed = expectation(description: "both Ledgers listed")
        listed.assertForOverFulfill = false
        let viewModel = LedgerConnectViewModelImplementation(
            urlOpener: NoURLOpener(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.yield(first); $0.yield(first); $0.yield(second) } },
                connect: { id in
                    await attempts.record(id)
                    throw LedgerTransportError.pairingRemoved
                }
            ),
            readsAccounts: true
        )
        var devices: [TKListItemButton.Configuration] = []
        viewModel.didUpdateModel = { model in
            devices = model.devices
            if model.devices.count == 2 {
                listed.fulfill()
            }
        }

        viewModel.viewDidLoad()
        await fulfillment(of: [listed], timeout: 5)
        await waitUntil(attempts.changes) { await attempts.ids.count == 1 }
        let beforeChoice = await attempts.ids
        guard case .chevron = devices[1].accessory else {
            return XCTFail("the second Ledger is picked before the user taps it")
        }
        devices[1].tapClosure?()
        await waitUntil(attempts.changes) { await attempts.ids.count == 2 }
        viewModel.stopTasks()

        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(beforeChoice, [first.id])
        let connected = await attempts.ids
        XCTAssertEqual(connected, [first.id, second.id])
    }

    func testMultichainPairingGoesOnOnceTheLedgerIsConnected() async {
        let peripheral = LedgerPeripheral(id: UUID(), name: "Nano X 1A2B", device: LedgerDevice.bluetoothDevices[0])
        let enabled = expectation(description: "Continue enabled")
        enabled.assertForOverFulfill = false
        let viewModel = LedgerConnectViewModelImplementation(
            urlOpener: NoURLOpener(),
            transport: LedgerKit.LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.yield(peripheral) } },
                connect: { _ in
                    LedgerLink(exchange: { _ in
                        XCTFail("The Ledger is not asked for the TON app")
                        return Data([0x6D, 0x00])
                    }, disconnected: AsyncStream { _ in }, close: {})
                }
            ),
            readsAccounts: false
        )
        var model: LedgerConnectView.Model?
        viewModel.didUpdateModel = {
            model = $0
            if $0.continuteButton.isEnabled {
                enabled.fulfill()
            }
        }
        var connected: (accounts: [LedgerAccount], deviceId: String)?
        viewModel.didConnect = { accounts, deviceId, _, _ in
            connected = (accounts, deviceId)
        }

        viewModel.viewDidLoad()
        await fulfillment(of: [enabled], timeout: 1)
        model?.continuteButton.action?()
        viewModel.stopTasks()

        XCTAssertEqual(connected?.deviceId, peripheral.id.uuidString)
        XCTAssertEqual(connected?.accounts.count, 0)
        XCTAssertEqual(model?.contentViewModel.stepModels.count, 1, "No step asks for the TON app")
    }

    func testTheTonAppIsAskedForAgainAfterTheUserRefusesIt() async throws {
        let replies = Replies([dashboard, Data([0x55, 0x01]), dashboard, Data([0x90, 0x00]), tonApp])
        let link = LedgerLink(exchange: { _ in await replies.next() }, disconnected: AsyncStream { _ in }, close: {})
        var answers: [Bool] = []

        let version = try await link.waitForApp(.ton, sleep: { _ in }) { answers.append($0) }

        XCTAssertEqual(version, "2.7.0")
        XCTAssertEqual(answers, [false])
    }

    func testAMissingTonAppIsReportedUntilItIsInstalled() async throws {
        let replies = Replies([dashboard, Data([0x68, 0x07]), dashboard, Data([0x90, 0x00]), tonApp])
        let link = LedgerLink(exchange: { _ in await replies.next() }, disconnected: AsyncStream { _ in }, close: {})
        var answers: [Bool] = []

        let version = try await link.waitForApp(.ton, sleep: { _ in }) { answers.append($0) }

        XCTAssertEqual(version, "2.7.0")
        XCTAssertEqual(answers, [true])
    }
}

private let dashboard = Data([0x01, 0x05]) + Data("BOLOS".utf8) + Data([0x05]) + Data("1.0.0".utf8) + Data([0x90, 0x00])
private let tonApp = Data([0x01, 0x03]) + Data("TON".utf8) + Data([0x05]) + Data("2.7.0".utf8) + Data([0x90, 0x00])

private actor Replies {
    private var replies: [Data]

    init(_ replies: [Data]) {
        self.replies = replies
    }

    func next() -> Data {
        replies.isEmpty ? Data([0x6F, 0x00]) : replies.removeFirst()
    }
}

private actor Attempts {
    private(set) var ids: [UUID] = []
    nonisolated let changes = TestSignal()

    func record(_ id: UUID) {
        ids.append(id)
        changes.send()
    }
}

private struct NoURLOpener: URLOpener {
    func open(url _: URL) {}

    func canOpen(url _: URL) -> Bool {
        false
    }
}

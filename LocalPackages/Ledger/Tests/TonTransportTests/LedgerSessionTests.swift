import CoreBluetooth
@testable import LedgerKit
import TKTestSupport
import XCTest

private let untilCancelled = TestGate()

final class LedgerSessionTests: XCTestCase {
    func testSwitchingAppsSurvivesTheLinkDroppingInBetween() async throws {
        let beforeDrop = FakeDevice(replies: [appInfo("TON", "2.7.0"), ok])
        let afterDrop = FakeDevice(replies: [appInfo("BOLOS", "1.0.1"), ok, appInfo("Ethereum", "1.12.0"), Data("7e5f".utf8) + ok])
        let connections = Connections([beforeDrop, afterDrop])
        let phases = Phases()
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), pollInterval: 0.001) { phases.append($0) }

        let reply = try await session.run(on: .ethereum) { link in
            try await link.send(cla: 0xE0, ins: 0x02)
        }

        XCTAssertEqual(reply, Data("7e5f".utf8))
        let opened = await connections.count
        XCTAssertEqual(opened, 2)
        let sentBeforeDrop = await beforeDrop.sent
        XCTAssertEqual(sentBeforeDrop, ["b001000000", "b0a7000000", "b001000000"])
        XCTAssertEqual(phases.all.last, .running(.ethereum))
    }

    func testBluetoothTimeoutWhileConnectingIsRetried() async throws {
        let device = FakeDevice(replies: [appInfo("TON", "2.7.0"), Data("key".utf8) + ok])
        let connections = Connections(attempts: [
            { throw bluetoothTimeout() },
            { device.link },
        ])
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), pollInterval: 0) { _ in }

        try await session.connect()
        let reply = try await session.run(on: .ton) { link in
            try await link.send(cla: 0xE0, ins: 0x02)
        }

        XCTAssertEqual(reply, Data("key".utf8))
        let opened = await connections.count
        XCTAssertEqual(opened, 2)
    }

    func testBluetoothTimeoutWhileReadingKeysReconnectsAndRetriesTheRead() async throws {
        let closes = Closes()
        let broken = LedgerLink(
            exchange: { apdu in
                if apdu[0] == 0xB0 {
                    return appInfo("TON", "2.7.0")
                }
                throw bluetoothTimeout()
            },
            disconnected: AsyncStream { $0.finish() },
            close: { closes.record() }
        )
        let next = FakeDevice(replies: [appInfo("TON", "2.7.0"), Data("key".utf8) + ok])
        let connections = Connections(links: [broken, next.link])
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), pollInterval: 0) { _ in }

        let reply = try await session.run(on: .ton, retryBody: true) { link in
            try await link.send(cla: 0xE0, ins: 0x02)
        }

        XCTAssertEqual(reply, Data("key".utf8))
        XCTAssertEqual(closes.count, 1)
        let opened = await connections.count
        XCTAssertEqual(opened, 2)
    }

    func testSigningBodyIsNotReplayedAfterALinkLoss() async {
        let closes = Closes()
        let confirmations = Closes()
        let device = FakeDevice(replies: [appInfo("TON", "2.7.0")])
        let link = LedgerLink(exchange: device.link.exchange, disconnected: AsyncStream { $0.finish() }, close: { closes.record() })
        let connections = Connections(links: [link])
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), pollInterval: 0) { _ in }

        do {
            _ = try await session.run(on: .ton) { _ in
                confirmations.record()
                throw bluetoothTimeout()
            }
            XCTFail("A lost signing reply must reach the caller without another confirmation")
        } catch {
            assertTimeout(error)
        }
        let attempts = await connections.count
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(confirmations.count, 1)
        XCTAssertEqual(closes.count, 1)
    }

    func testBluetoothTimeoutWhileSwitchingAppsReconnects() async throws {
        let broken = LedgerLink(
            exchange: { apdu in
                if apdu[1] == 0x01 {
                    return appInfo("TON", "2.7.0")
                }
                throw bluetoothTimeout()
            },
            disconnected: AsyncStream { $0.finish() },
            close: {}
        )
        let next = FakeDevice(replies: [appInfo("BOLOS", "1.0.1"), ok, appInfo("Ethereum", "1.12.0"), Data("key".utf8) + ok])
        let connections = Connections(links: [broken, next.link])
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), pollInterval: 0) { _ in }

        let reply = try await session.run(on: .ethereum) { link in
            try await link.send(cla: 0xE0, ins: 0x02)
        }

        XCTAssertEqual(reply, Data("key".utf8))
        let opened = await connections.count
        XCTAssertEqual(opened, 2)
    }

    func testRepeatedConnectionFailuresExhaustTheSharedRecoveryBudget() async {
        let clock = TestTime()
        let connections = Connections(attempts: [10.0, 10.0, 5.0].map { elapsed in
            {
                clock.advance(elapsed)
                throw bluetoothTimeout()
            }
        })
        let session = LedgerSession(
            transport: connections.transport,
            peripheralID: UUID(),
            pollInterval: 0,
            timing: clock.timing
        ) { _ in }

        do {
            try await session.connect()
            XCTFail("Repeated timeouts must exhaust the recovery budget")
        } catch {
            assertTimeout(error)
        }
        let attempts = await connections.count
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(clock.now, 25)
    }

    func testANewOperationGetsAFreshRecoveryBudget() async throws {
        let clock = TestTime()
        let device = FakeDevice(replies: [])
        let connections = Connections(attempts: [
            {
                clock.advance(25)
                throw bluetoothTimeout()
            },
            {
                clock.advance(24)
                return device.link
            },
        ])
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), pollInterval: 0, timing: clock.timing) { _ in }
        do {
            try await session.connect()
            XCTFail("The first operation must exhaust its budget")
        } catch {
            assertTimeout(error)
        }

        try await session.connect()

        let attempts = await connections.count
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(clock.now, 49)
    }

    func testReconnectingAfterReadFailuresDoesNotResetTheRecoveryBudget() async {
        let clock = TestTime()
        let closes = Closes()
        let broken = LedgerLink(
            exchange: { _ in throw bluetoothTimeout() },
            disconnected: AsyncStream { $0.finish() },
            close: { closes.record() }
        )
        let connections = Connections(attempts: (0 ..< 5).map { _ in
            {
                clock.advance(5)
                return broken
            }
        })
        let session = LedgerSession(
            transport: connections.transport,
            peripheralID: UUID(),
            pollInterval: 0,
            timing: clock.timing
        ) { _ in }

        do {
            _ = try await session.run(on: .ton) { _ in () }
            XCTFail("A new connection must not restart the recovery budget")
        } catch {
            assertTimeout(error)
        }
        let attempts = await connections.count
        XCTAssertEqual(attempts, 5)
        XCTAssertEqual(closes.count, 5)
    }

    func testRetryDelayConsumesTheRemainingRecoveryBudget() async {
        let clock = TestTime()
        let connections = Connections(attempts: [{
            clock.advance(24)
            throw bluetoothTimeout()
        }])
        let timing = LedgerSession.Timing(now: { clock.now }, sleep: { interval in
            if interval == 1 {
                clock.advance(interval)
            } else {
                try await untilCancelled.wait()
            }
        })
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), timing: timing) { _ in }

        do {
            try await session.connect()
            XCTFail("The retry delay must consume the last second of the budget")
        } catch {
            assertTimeout(error)
        }
        let attempts = await connections.count
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(clock.now, 25)
    }

    func testAConnectionReturnedAfterTheTimeoutIsClosed() async {
        let connecting = expectation(description: "connection started")
        let timerArmed = expectation(description: "connection timeout armed")
        let expiry = TestGate()
        let clock = TestTime()
        let closes = Closes()
        let late = LedgerLink(exchange: { _ in ok }, disconnected: AsyncStream { $0.finish() }, close: { closes.record() })
        let connections = Connections(attempts: [{
            connecting.fulfill()
            do {
                try await untilCancelled.wait()
            } catch is CancellationError {
                return late
            }
            return late
        }])
        let timing = LedgerSession.Timing(now: { clock.now }, sleep: { interval in
            timerArmed.fulfill()
            try await expiry.wait()
            clock.advance(interval)
        })
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), timing: timing) { _ in }
        let task = Task { try await session.connect() }
        await fulfillment(of: [connecting, timerArmed], timeout: 1)

        await expiry.open()
        do {
            try await task.value
            XCTFail("A connection returned after the timeout must not be kept")
        } catch {
            assertTimeout(error)
        }
        XCTAssertEqual(closes.count, 1)
    }

    func testAConnectionThatNeverCompletesTimesOutAndIsCancelled() async {
        let connecting = expectation(description: "connection started")
        let timerArmed = expectation(description: "connection timeout armed")
        let cancelled = expectation(description: "pending connection cancelled")
        let expiry = TestGate()
        let clock = TestTime()
        let connections = Connections(attempts: [{
            connecting.fulfill()
            do {
                try await untilCancelled.wait()
            } catch {
                cancelled.fulfill()
                throw error
            }
            throw LedgerTransportError.invalidResponse
        }])
        let timing = LedgerSession.Timing(now: { clock.now }, sleep: { interval in
            timerArmed.fulfill()
            try await expiry.wait()
            clock.advance(interval)
        })
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), timing: timing) { _ in }
        let task = Task { try await session.connect() }
        await fulfillment(of: [connecting, timerArmed], timeout: 1)

        await expiry.open()
        do {
            try await task.value
            XCTFail("A pending connection must time out")
        } catch {
            assertTimeout(error)
        }
        await fulfillment(of: [cancelled], timeout: 1)
        let attempts = await connections.count
        XCTAssertEqual(attempts, 1)
    }

    func testCancellationDuringRecoveryStopsRetrying() async {
        let retrying = expectation(description: "waiting before retry")
        let connections = Connections(attempts: [{ throw bluetoothTimeout() }])
        let timing = LedgerSession.Timing(sleep: { interval in
            if interval == 1 {
                retrying.fulfill()
            }
            try await untilCancelled.wait()
        })
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), timing: timing) { _ in }
        let task = Task { try await session.connect() }
        await fulfillment(of: [retrying], timeout: 1)

        task.cancel()
        do {
            try await task.value
            XCTFail("A cancelled recovery must stop")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let attempts = await connections.count
        XCTAssertEqual(attempts, 1)
    }

    func testWaitingOnTheDeviceDoesNotConsumeTheRecoveryBudget() async throws {
        let clock = TestTime()
        let slow = LedgerLink(
            exchange: { _ in
                clock.advance(60)
                return appInfo("TON", "2.7.0")
            },
            disconnected: AsyncStream { $0.finish() },
            close: {}
        )
        let connections = Connections(attempts: [
            { throw bluetoothTimeout() },
            { slow },
        ])
        let session = LedgerSession(
            transport: connections.transport,
            peripheralID: UUID(),
            pollInterval: 0,
            timing: clock.timing
        ) { _ in }

        let result = try await session.run(on: .ton) { _ in 42 }

        XCTAssertEqual(result, 42)
        XCTAssertEqual(clock.now, 60)
        let attempts = await connections.count
        XCTAssertEqual(attempts, 2)
    }

    func testWaitingForBluetoothDoesNotConsumeTheRecoveryBudget() async throws {
        let waiting = expectation(description: "waiting for Bluetooth")
        let clock = TestTime()
        let states = AsyncStream.makeStream(of: CBManagerState.self)
        states.continuation.yield(.poweredOff)
        let device = FakeDevice(replies: [])
        let connections = Connections(attempts: [
            { throw LedgerTransportError.bluetoothUnavailable },
            { device.link },
        ])
        let transport = LedgerTransport(
            bluetoothState: {
                waiting.fulfill()
                return states.stream
            },
            scan: { AsyncStream { $0.finish() } },
            connect: connections.transport.connect
        )
        let session = LedgerSession(transport: transport, peripheralID: UUID(), pollInterval: 0, timing: clock.timing) { _ in }
        let task = Task { try await session.connect() }
        await fulfillment(of: [waiting], timeout: 1)

        clock.advance(100)
        states.continuation.yield(.poweredOn)
        try await task.value
        states.continuation.finish()

        let attempts = await connections.count
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(clock.now, 100)
    }

    func testWaitingForBluetoothCanBeCancelled() async {
        let waiting = expectation(description: "waiting for Bluetooth")
        let states = AsyncStream.makeStream(of: CBManagerState.self)
        states.continuation.yield(.poweredOff)
        let connections = Connections(attempts: [{ throw LedgerTransportError.bluetoothUnavailable }])
        let transport = LedgerTransport(
            bluetoothState: {
                waiting.fulfill()
                return states.stream
            },
            scan: { AsyncStream { $0.finish() } },
            connect: connections.transport.connect
        )
        let session = LedgerSession(transport: transport, peripheralID: UUID()) { _ in }
        let task = Task { try await session.connect() }
        await fulfillment(of: [waiting], timeout: 1)

        task.cancel()
        do {
            try await task.value
            XCTFail("Waiting for Bluetooth must stop when cancelled")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        states.continuation.finish()
        let attempts = await connections.count
        XCTAssertEqual(attempts, 1)
    }

    func testUnsupportedBluetoothEndsRecoveryAndReportsConnecting() async {
        let phases = Phases()
        let device = FakeDevice(replies: [appInfo("TON", "2.7.0")])
        let connections = Connections([device])
        let transport = LedgerTransport(
            bluetoothState: { AsyncStream { $0.yield(.unsupported); $0.finish() } },
            scan: { AsyncStream { $0.finish() } },
            connect: connections.transport.connect
        )
        let session = LedgerSession(transport: transport, peripheralID: UUID(), pollInterval: 0) { phases.append($0) }

        do {
            _ = try await session.run(on: .ton, retryBody: true) { _ in throw LedgerTransportError.bluetoothUnavailable }
            XCTFail("Unsupported Bluetooth must not keep waiting")
        } catch LedgerTransportError.bluetoothUnsupported {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(phases.all.suffix(2), [.running(.ton), .connecting])
        let attempts = await connections.count
        XCTAssertEqual(attempts, 1)
    }

    func testTransientBluetoothStatesReturnToTheRetryLoop() async throws {
        for state in [CBManagerState.unknown, .resetting] {
            let connections = Connections(attempts: [
                { throw LedgerTransportError.bluetoothUnavailable },
                { FakeDevice(replies: []).link },
            ])
            let transport = LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(state); $0.finish() } },
                scan: { AsyncStream { $0.finish() } },
                connect: connections.transport.connect
            )
            let session = LedgerSession(transport: transport, peripheralID: UUID(), pollInterval: 0) { _ in }

            try await session.connect()

            let attempts = await connections.count
            XCTAssertEqual(attempts, 2)
        }
    }

    func testUnknownBluetoothStateUsesTheRecoveryBudget() async {
        let clock = TestTime()
        let connections = Connections(attempts: [{
            clock.advance(24)
            throw LedgerTransportError.bluetoothUnavailable
        }])
        let transport = LedgerTransport(
            bluetoothState: { AsyncStream { $0.yield(.unknown); $0.finish() } },
            scan: { AsyncStream { $0.finish() } },
            connect: connections.transport.connect
        )
        let timing = LedgerSession.Timing(now: { clock.now }, sleep: { interval in
            if interval == 1 {
                clock.advance(interval)
            } else {
                try await untilCancelled.wait()
            }
        })
        let session = LedgerSession(transport: transport, peripheralID: UUID(), timing: timing) { _ in }

        do {
            try await session.connect()
            XCTFail("A controller stuck in unknown must exhaust the budget")
        } catch {
            assertTimeout(error)
        }
        XCTAssertEqual(clock.now, 25)
        let attempts = await connections.count
        XCTAssertEqual(attempts, 1)
    }

    func testRemovedPairingIsNotRetried() async {
        let connections = Connections(attempts: [{ throw LedgerTransportError.pairingRemoved }])
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), pollInterval: 0) { _ in }

        do {
            try await session.connect()
            XCTFail("Lost pairing must reach the caller")
        } catch LedgerTransportError.pairingRemoved {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let attempts = await connections.count
        XCTAssertEqual(attempts, 1)
    }

    func testRefusalToOpenTheAppIsNotRetried() async {
        let device = FakeDevice(replies: [appInfo("BOLOS", "1.0.1"), Data([0x69, 0x85])])
        let phases = Phases()
        let session = LedgerSession(transport: Connections([device]).transport, peripheralID: UUID(), pollInterval: 0.001) { phases.append($0) }

        do {
            _ = try await session.run(on: .ethereum) { _ in () }
            XCTFail("A refusal must reach the caller")
        } catch let error as LedgerStatusError {
            XCTAssertTrue(error.isRefused)
        } catch {
            XCTFail("\(error)")
        }
        XCTAssertEqual(phases.all.last, .notOpened(.ethereum, isMissing: false))
    }

    func testConnectingAheadKeepsTheLinkForTheFirstApp() async throws {
        let device = FakeDevice(replies: [appInfo("TON", "2.7.0"), Data("7e5f".utf8) + ok])
        let connections = Connections([device])
        let phases = Phases()
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), pollInterval: 0.001) { phases.append($0) }

        try await session.connect()
        let reply = try await session.run(on: .ton) { link in
            try await link.send(cla: 0xE0, ins: 0x02)
        }

        XCTAssertEqual(reply, Data("7e5f".utf8))
        let opened = await connections.count
        XCTAssertEqual(opened, 1)
        XCTAssertEqual(phases.all, [.connecting, .connected, .openingApp(.ton), .running(.ton)])
    }

    func testARunStoppedMidwayDropsItsLinkAndTheNextRunConnectsAgain() async throws {
        let waiting = expectation(description: "an exchange waits for the Ledger")
        let closed = Closes()
        let silent = LedgerLink(
            exchange: { _ in
                waiting.fulfill()
                try await untilCancelled.wait()
                return ok
            },
            disconnected: AsyncStream { _ in },
            close: { closed.record() }
        )
        let next = FakeDevice(replies: [appInfo("TON", "2.7.0"), Data("7e5f".utf8) + ok])
        let connections = Connections(links: [silent, next.link])
        let session = LedgerSession(transport: connections.transport, peripheralID: UUID(), pollInterval: 0.001) { _ in }

        let stopped = Task { try await session.run(on: .ethereum) { _ in () } }
        await fulfillment(of: [waiting], timeout: 1)
        stopped.cancel()
        _ = await stopped.result
        let reply = try await session.run(on: .ton) { link in
            try await link.send(cla: 0xE0, ins: 0x02)
        }

        XCTAssertEqual(closed.count, 1)
        XCTAssertEqual(reply, Data("7e5f".utf8))
        let opened = await connections.count
        XCTAssertEqual(opened, 2)
    }

    func testAMissingAppIsReportedAsNotOpened() async {
        let device = FakeDevice(replies: [appInfo("BOLOS", "1.0.1"), Data([0x68, 0x07])])
        let phases = Phases()
        let session = LedgerSession(transport: Connections([device]).transport, peripheralID: UUID(), pollInterval: 0.001) { phases.append($0) }

        _ = try? await session.run(on: .ethereum) { _ in () }

        XCTAssertEqual(phases.all.last, .notOpened(.ethereum, isMissing: true))
    }
}

private let ok = Data([0x90, 0x00])

private func appInfo(_ name: String, _ version: String) -> Data {
    Data([0x01, UInt8(name.utf8.count)]) + Data(name.utf8) + Data([UInt8(version.utf8.count)]) + Data(version.utf8) + ok
}

private actor Connections {
    private var attempts: [@Sendable () async throws -> LedgerLink]
    private(set) var count = 0

    init(attempts: [@Sendable () async throws -> LedgerLink]) {
        self.attempts = attempts
    }

    init(links: [LedgerLink]) {
        self.init(attempts: links.map { link in { link } })
    }

    init(_ devices: [FakeDevice]) {
        self.init(links: devices.map(\.link))
    }

    nonisolated var transport: LedgerTransport {
        LedgerTransport(
            bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
            scan: { AsyncStream { $0.finish() } },
            connect: { _ in try await self.connect() }
        )
    }

    private func connect() async throws -> LedgerLink {
        count += 1
        guard !attempts.isEmpty else {
            throw LedgerTransportError.invalidRequest
        }
        return try await attempts.removeFirst()()
    }
}

private final class Closes: @unchecked Sendable { // `closes` is guarded by `lock`
    private let lock = NSLock()
    private var closes = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return closes
    }

    func record() {
        lock.lock()
        defer { lock.unlock() }
        closes += 1
    }
}

private final class Phases: @unchecked Sendable { // `phases` is guarded by `lock`
    private let lock = NSLock()
    private var phases: [LedgerSession.Phase] = []

    var all: [LedgerSession.Phase] {
        lock.lock()
        defer { lock.unlock() }
        return phases
    }

    func append(_ phase: LedgerSession.Phase) {
        lock.lock()
        defer { lock.unlock() }
        phases.append(phase)
    }
}

private func bluetoothTimeout() -> Error {
    LedgerTransportError.fromBluetooth(NSError(domain: CBErrorDomain, code: 6))
}

private func assertTimeout(_ error: Error, file: StaticString = #filePath, line: UInt = #line) {
    guard case LedgerTransportError.timeout = error else {
        return XCTFail("Unexpected error: \(error)", file: file, line: line)
    }
}

private final class TestTime: @unchecked Sendable { // `time` is guarded by `lock`
    private let lock = NSLock()
    private var time: TimeInterval = 0

    var now: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return time
    }

    func advance(_ interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        time += interval
    }

    var timing: LedgerSession.Timing {
        LedgerSession.Timing(now: { self.now }, sleep: { interval in
            if interval > 0 {
                try await untilCancelled.wait()
            }
        })
    }
}

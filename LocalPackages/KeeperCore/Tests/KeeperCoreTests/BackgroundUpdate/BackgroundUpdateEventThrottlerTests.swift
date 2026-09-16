import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class BackgroundUpdateEventThrottlerTests: XCTestCase {
    func test_burstIsCollapsedIntoLeadingAndTrailingEmission() async {
        let fixture = await makeFixture(interval: 2)
        defer { fixture.eventsTask.cancel() }

        let leading = expectNextEvent(fixture.recorder)
        let scheduled = expectNextSleep(fixture.sleeper)
        for lt in 1 ... 20 {
            fixture.throttler.receive(makeEvent(lt: Int64(lt)))
        }
        await fulfillment(of: [leading, scheduled], timeout: 1)

        XCTAssertEqual(fixture.recorder.values, [1])
        XCTAssertEqual(fixture.sleeper.delays, [2])

        let trailing = expectNextEvent(fixture.recorder)
        fixture.sleeper.resumeNext()
        await fulfillment(of: [trailing], timeout: 1)

        XCTAssertEqual(fixture.recorder.values, [1, 20])
    }

    func test_eventOutsideIntervalIsEmittedImmediately() async {
        let fixture = await makeFixture(interval: 2)
        defer { fixture.eventsTask.cancel() }

        let first = expectNextEvent(fixture.recorder)
        fixture.throttler.receive(makeEvent(lt: 1))
        await fulfillment(of: [first], timeout: 1)

        fixture.clock.advance(by: 2)
        let second = expectNextEvent(fixture.recorder)
        fixture.throttler.receive(makeEvent(lt: 2))
        await fulfillment(of: [second], timeout: 1)

        XCTAssertEqual(fixture.recorder.values, [1, 2])
        XCTAssertTrue(fixture.sleeper.delays.isEmpty)
    }

    func test_trailingEmissionOpensNewInterval() async {
        let fixture = await makeFixture(interval: 2)
        defer { fixture.eventsTask.cancel() }

        let leading = expectNextEvent(fixture.recorder)
        let firstSchedule = expectNextSleep(fixture.sleeper)
        fixture.throttler.receive(makeEvent(lt: 1))
        fixture.throttler.receive(makeEvent(lt: 2))
        await fulfillment(of: [leading, firstSchedule], timeout: 1)

        fixture.clock.advance(by: 2)
        let firstTrailing = expectNextEvent(fixture.recorder)
        fixture.sleeper.resumeNext()
        await fulfillment(of: [firstTrailing], timeout: 1)

        let secondSchedule = expectNextSleep(fixture.sleeper)
        fixture.throttler.receive(makeEvent(lt: 3))
        await fulfillment(of: [secondSchedule], timeout: 1)

        XCTAssertEqual(fixture.recorder.values, [1, 2])
        XCTAssertEqual(fixture.sleeper.delays.count, 2)

        fixture.clock.advance(by: 2)
        let secondTrailing = expectNextEvent(fixture.recorder)
        fixture.sleeper.resumeNext()
        await fulfillment(of: [secondTrailing], timeout: 1)

        XCTAssertEqual(fixture.recorder.values, [1, 2, 3])
    }

    func test_cancelledTrailingTaskCannotReorderEmissions() async {
        let fixture = await makeFixture(interval: 2)
        defer { fixture.eventsTask.cancel() }

        let first = expectNextEvent(fixture.recorder)
        fixture.throttler.receive(makeEvent(lt: 1))
        await fulfillment(of: [first], timeout: 1)

        fixture.clock.advance(by: 0.5)
        let staleSchedule = expectNextSleep(fixture.sleeper)
        fixture.throttler.receive(makeEvent(lt: 2))
        await fulfillment(of: [staleSchedule], timeout: 1)

        fixture.clock.advance(by: 2.5)
        let third = expectNextEvent(fixture.recorder)
        fixture.throttler.receive(makeEvent(lt: 3))
        await fulfillment(of: [third], timeout: 1)

        fixture.clock.advance(by: 0.1)
        let replacementSchedule = expectNextSleep(fixture.sleeper)
        fixture.throttler.receive(makeEvent(lt: 4))
        await fulfillment(of: [replacementSchedule], timeout: 1)

        let staleEmission = expectNextEvent(fixture.recorder, inverted: true)
        fixture.sleeper.resumeNext()
        await fulfillment(of: [staleEmission], timeout: 0.1)

        let replacementEmission = expectNextEvent(fixture.recorder)
        fixture.sleeper.resumeNext()
        await fulfillment(of: [replacementEmission], timeout: 1)

        XCTAssertEqual(fixture.recorder.values, [1, 3, 4])
    }

    func test_finishTerminatesOutputAndDropsPendingTrailingEvent() async {
        let clock = ControlledClock()
        let sleeper = ControlledSleeper()
        let recorder = EventRecorder()
        let throttler = BackgroundUpdateEventThrottler(
            interval: 2,
            now: { clock.now() },
            sleep: { try await sleeper.sleep(delay: $0) }
        )
        let events = await throttler.events
        let finished = expectation(description: "output stream finished")
        let eventsTask = Task { [events] in
            for await event in events {
                recorder.record(event.lt)
            }
            finished.fulfill()
        }
        defer { eventsTask.cancel() }

        let leading = expectNextEvent(recorder)
        let scheduled = expectNextSleep(sleeper)
        throttler.receive(makeEvent(lt: 1))
        throttler.receive(makeEvent(lt: 2))
        await fulfillment(of: [leading, scheduled], timeout: 1)

        throttler.finish()
        throttler.finish()
        await fulfillment(of: [finished], timeout: 1)

        sleeper.resumeNext()
        XCTAssertEqual(recorder.values, [1])
    }

    private func makeFixture(interval: TimeInterval) async -> Fixture {
        let clock = ControlledClock()
        let sleeper = ControlledSleeper()
        let recorder = EventRecorder()
        let throttler = BackgroundUpdateEventThrottler(
            interval: interval,
            now: { clock.now() },
            sleep: { try await sleeper.sleep(delay: $0) }
        )
        let events = await throttler.events
        let eventsTask = Task { [events] in
            for await event in events {
                recorder.record(event.lt)
            }
        }
        return Fixture(
            throttler: throttler,
            clock: clock,
            sleeper: sleeper,
            recorder: recorder,
            eventsTask: eventsTask
        )
    }

    private func expectNextEvent(
        _ recorder: EventRecorder,
        inverted: Bool = false
    ) -> XCTestExpectation {
        let expectation = expectation(description: "event emitted")
        expectation.isInverted = inverted
        recorder.onNextValue { expectation.fulfill() }
        return expectation
    }

    private func expectNextSleep(_ sleeper: ControlledSleeper) -> XCTestExpectation {
        let expectation = expectation(description: "trailing emission scheduled")
        sleeper.onNextSleep { expectation.fulfill() }
        return expectation
    }

    private func makeEvent(lt: Int64) -> BackgroundUpdateEvent {
        BackgroundUpdateEvent(wallet: .testWallet, lt: lt, txHash: "hash-\(lt)")
    }
}

private struct Fixture {
    let throttler: BackgroundUpdateEventThrottler
    let clock: ControlledClock
    let sleeper: ControlledSleeper
    let recorder: EventRecorder
    let eventsTask: Task<Void, Never>
}

private final class ControlledClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 0)

    func now() -> Date {
        lock.withLock { date }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock {
            date = date.addingTimeInterval(interval)
        }
    }
}

private final class ControlledSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [CheckedContinuation<Void, Never>]()
    private var recordedDelays = [TimeInterval]()
    private var nextSleepHandler: (() -> Void)?

    var delays: [TimeInterval] {
        lock.withLock { recordedDelays }
    }

    func sleep(delay: TimeInterval) async throws {
        await withCheckedContinuation { continuation in
            let handler = lock.withLock { () -> (() -> Void)? in
                continuations.append(continuation)
                recordedDelays.append(delay)
                defer { nextSleepHandler = nil }
                return nextSleepHandler
            }
            handler?()
        }
    }

    func onNextSleep(_ handler: @escaping () -> Void) {
        lock.withLock {
            nextSleepHandler = handler
        }
    }

    func resumeNext() {
        let continuation = lock.withLock { continuations.removeFirst() }
        continuation.resume()
    }
}

private final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedValues = [Int64]()
    private var nextValueHandler: (() -> Void)?

    var values: [Int64] {
        lock.withLock { recordedValues }
    }

    func record(_ value: Int64) {
        let handler = lock.withLock { () -> (() -> Void)? in
            recordedValues.append(value)
            defer { nextValueHandler = nil }
            return nextValueHandler
        }
        handler?()
    }

    func onNextValue(_ handler: @escaping () -> Void) {
        lock.withLock {
            nextValueHandler = handler
        }
    }
}

private extension Wallet {
    static let testWallet: Wallet = {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 2, count: 32))
        return Wallet(
            id: "background-update-throttler-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v5R1)),
            metaData: WalletMetaData(label: "test", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }()
}

import Foundation
@testable import KeeperCore
import TronSwiftAPI
import XCTest

final class WalletMigrationTronConfirmationWaiterTests: XCTestCase {
    func test_confirmationIsDetectedOnFirstPoll() async throws {
        let clock = TronConfirmationTestClock()
        let stub = TronConfirmationInfoStub(
            clock: clock,
            responseAt: 0,
            response: .init(id: "tx", blockNumber: 1, receiptResult: nil)
        )
        let waiter = makeWaiter(loadInfo: stub, clock: clock)

        let outcome = try await waiter.wait(txId: "tx")

        XCTAssertEqual(outcome, .confirmed)
        XCTAssertEqual(stub.pollCount, 1)
        XCTAssertEqual(clock.elapsed, 0)
    }

    func test_confirmationIsDetectedAfterPendingPolls() async throws {
        let clock = TronConfirmationTestClock()
        let stub = TronConfirmationInfoStub(
            clock: clock,
            responseAt: 6,
            response: .init(id: "tx", blockNumber: 42, receiptResult: "SUCCESS")
        )
        let waiter = makeWaiter(loadInfo: stub, clock: clock)

        let outcome = try await waiter.wait(txId: "tx")

        XCTAssertEqual(outcome, .confirmed)
        XCTAssertEqual(clock.elapsed, 6)
    }

    func test_failedReceiptIsReported() async throws {
        let clock = TronConfirmationTestClock()
        let stub = TronConfirmationInfoStub(
            clock: clock,
            responseAt: 0,
            response: .init(id: "tx", blockNumber: 1, receiptResult: "OUT_OF_ENERGY")
        )
        let waiter = makeWaiter(loadInfo: stub, clock: clock)

        let outcome = try await waiter.wait(txId: "tx")

        XCTAssertEqual(outcome, .failed(result: "OUT_OF_ENERGY"))
    }

    func test_deadlineIsReportedRatherThanThrown() async throws {
        let clock = TronConfirmationTestClock()
        let stub = TronConfirmationInfoStub(clock: clock, responseAt: .infinity, response: nil)
        let waiter = makeWaiter(loadInfo: stub, clock: clock, timeout: 9)

        let outcome = try await waiter.wait(txId: "tx")

        XCTAssertEqual(outcome, .timedOut)
        XCTAssertGreaterThanOrEqual(clock.elapsed, 9)
    }

    func test_transientLoadErrorsDoNotAbortTheWait() async throws {
        let clock = TronConfirmationTestClock()
        let stub = TronConfirmationInfoStub(
            clock: clock,
            responseAt: 3,
            response: .init(id: "tx", blockNumber: 1, receiptResult: "SUCCESS"),
            failingReadsAt: [0]
        )
        let waiter = makeWaiter(loadInfo: stub, clock: clock)

        let outcome = try await waiter.wait(txId: "tx")

        XCTAssertEqual(outcome, .confirmed)
        XCTAssertEqual(clock.elapsed, 3)
    }

    func test_cancellationIsPropagated() async {
        let clock = TronConfirmationTestClock()
        let stub = TronConfirmationInfoStub(clock: clock, responseAt: .infinity, response: nil)
        let waiter = makeWaiter(loadInfo: stub, clock: clock)

        let task = Task {
            try await waiter.wait(txId: "tx")
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to surface")
        } catch is CancellationError {} catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    private func makeWaiter(
        loadInfo: TronConfirmationInfoStub,
        clock: TronConfirmationTestClock,
        timeout: TimeInterval = 120
    ) -> WalletMigrationTronConfirmationWaiter {
        WalletMigrationTronConfirmationWaiter(
            loadInfo: { txId in
                try await loadInfo.loadInfo(txId: txId)
            },
            pollInterval: 3,
            timeout: timeout,
            sleep: { delay in clock.advance(by: delay) },
            now: { clock.now() }
        )
    }
}

private final class TronConfirmationTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var offset: TimeInterval = 0

    var elapsed: TimeInterval {
        lock.withLock { offset }
    }

    func now() -> Date {
        Date(timeIntervalSince1970: 1_000_000 + elapsed)
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { offset += interval }
    }
}

private enum TronConfirmationStubError: Error {
    case transient
}

private final class TronConfirmationInfoStub: @unchecked Sendable {
    private let clock: TronConfirmationTestClock
    private let responseAt: TimeInterval
    private let response: TronTransactionInfoResponse?
    private let failingReadsAt: Set<TimeInterval>
    private let lock = NSLock()
    private var polls = 0

    var pollCount: Int {
        lock.withLock { polls }
    }

    init(
        clock: TronConfirmationTestClock,
        responseAt: TimeInterval,
        response: TronTransactionInfoResponse?,
        failingReadsAt: Set<TimeInterval> = []
    ) {
        self.clock = clock
        self.responseAt = responseAt
        self.response = response
        self.failingReadsAt = failingReadsAt
    }

    func loadInfo(txId _: String) async throws -> TronTransactionInfoResponse? {
        let elapsed = clock.elapsed
        lock.withLock { polls += 1 }
        if failingReadsAt.contains(elapsed) {
            throw TronConfirmationStubError.transient
        }
        return elapsed >= responseAt ? response : nil
    }
}

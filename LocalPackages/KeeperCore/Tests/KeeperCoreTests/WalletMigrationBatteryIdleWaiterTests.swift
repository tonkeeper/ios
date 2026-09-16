import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class WalletMigrationBatteryIdleWaiterTests: XCTestCase {
    func test_idleIsDetectedWithinOnePollOfClearing() async throws {
        let clock = BatteryIdleTestClock()
        let hasPending = BatteryIdlePendingStub(clock: clock, clearsAt: 5.5)
        let waiter = makeWaiter(hasPending: hasPending, clock: clock)

        let idle = try await waiter.wait(wallet: .batteryIdleTestWallet)

        XCTAssertTrue(idle)
        XCTAssertEqual(clock.elapsed, 5.5)
        XCTAssertEqual(hasPending.pollCount, 4)
    }

    func test_deadlineIsReportedRatherThanThrown() async throws {
        let clock = BatteryIdleTestClock()
        let hasPending = BatteryIdlePendingStub(clock: clock, clearsAt: .infinity)
        let waiter = makeWaiter(hasPending: hasPending, clock: clock, timeout: 10)

        let idle = try await waiter.wait(wallet: .batteryIdleTestWallet)

        XCTAssertFalse(idle)
        XCTAssertGreaterThanOrEqual(clock.elapsed, 10)
    }

    func test_transientStatusErrorsDoNotAbortTheWait() async throws {
        let clock = BatteryIdleTestClock()
        let hasPending = BatteryIdlePendingStub(
            clock: clock,
            clearsAt: 4,
            failingReadsAt: [1]
        )
        let waiter = makeWaiter(hasPending: hasPending, clock: clock)

        let idle = try await waiter.wait(wallet: .batteryIdleTestWallet)

        XCTAssertTrue(idle)
        XCTAssertEqual(clock.elapsed, 4)
    }

    func test_cancellationIsPropagated() async {
        let clock = BatteryIdleTestClock()
        let hasPending = BatteryIdlePendingStub(clock: clock, clearsAt: .infinity)
        let waiter = makeWaiter(hasPending: hasPending, clock: clock)

        let task = Task {
            try await waiter.wait(wallet: .batteryIdleTestWallet)
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
        hasPending: BatteryIdlePendingStub,
        clock: BatteryIdleTestClock,
        timeout: TimeInterval = 60
    ) -> WalletMigrationBatteryIdleWaiter {
        WalletMigrationBatteryIdleWaiter(
            hasPendingTransactions: { wallet in
                try await hasPending.hasPendingTransactions(wallet: wallet)
            },
            timeout: timeout,
            sleep: { delay in clock.advance(by: delay) },
            now: { clock.now() }
        )
    }
}

private final class BatteryIdleTestClock: @unchecked Sendable {
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

private enum BatteryIdleStubError: Error {
    case rateLimited
}

private final class BatteryIdlePendingStub: @unchecked Sendable {
    private let clock: BatteryIdleTestClock
    private let clearsAt: TimeInterval
    private let failingReadsAt: Set<TimeInterval>
    private let lock = NSLock()
    private var polls = 0

    var pollCount: Int {
        lock.withLock { polls }
    }

    init(
        clock: BatteryIdleTestClock,
        clearsAt: TimeInterval,
        failingReadsAt: Set<TimeInterval> = []
    ) {
        self.clock = clock
        self.clearsAt = clearsAt
        self.failingReadsAt = failingReadsAt
    }

    func hasPendingTransactions(wallet _: KeeperCore.Wallet) async throws -> Bool {
        let elapsed = clock.elapsed
        lock.withLock { polls += 1 }
        if failingReadsAt.contains(elapsed) {
            throw BatteryIdleStubError.rateLimited
        }
        return elapsed < clearsAt
    }
}

private extension KeeperCore.Wallet {
    static var batteryIdleTestWallet: KeeperCore.Wallet {
        KeeperCore.Wallet(
            id: "battery-idle-waiter-test",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

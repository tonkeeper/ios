import Foundation
@testable import KeeperCore
import TonAPI
import TonSwift
import XCTest

/// TK-2837: a batch lands 5-9s after the broadcast, so the schedule is judged by how soon after the
/// real landing the waiter notices, and by how many requests it spends getting there.
final class WalletMigrationSeqnoWaiterTests: XCTestCase {
    func test_landingIsDetectedWithinOnePollOfHappening() async throws {
        let clock = SeqnoTestClock()
        let sendService = SeqnoStubSendService(clock: clock, advancesAt: 8)
        let waiter = makeWaiter(sendService: sendService, clock: clock)

        let reached = try await waiter.wait(wallet: .seqnoTestWallet, minimum: 1)

        XCTAssertTrue(reached)
        XCTAssertEqual(clock.elapsed, 8)
        XCTAssertEqual(sendService.loadCount, 5)
    }

    func test_deadlineIsReportedRatherThanThrown() async throws {
        let clock = SeqnoTestClock()
        let sendService = SeqnoStubSendService(clock: clock, advancesAt: .infinity)
        let waiter = makeWaiter(sendService: sendService, clock: clock, timeout: 10)

        let reached = try await waiter.wait(wallet: .seqnoTestWallet, minimum: 1)

        XCTAssertFalse(reached)
        XCTAssertGreaterThanOrEqual(clock.elapsed, 10)
    }

    func test_cancellationIsPropagated() async {
        let clock = SeqnoTestClock()
        let sendService = SeqnoStubSendService(clock: clock, advancesAt: .infinity)
        let waiter = makeWaiter(sendService: sendService, clock: clock)

        let task = Task {
            try await waiter.wait(wallet: .seqnoTestWallet, minimum: 1)
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
        sendService: SendService,
        clock: SeqnoTestClock,
        timeout: TimeInterval = 60
    ) -> WalletMigrationSeqnoWaiter {
        WalletMigrationSeqnoWaiter(
            sendService: sendService,
            timeout: timeout,
            sleep: { delay in clock.advance(by: delay) },
            now: { clock.now() }
        )
    }
}

private final class SeqnoTestClock: @unchecked Sendable {
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

private enum SeqnoStubError: Error {
    case rateLimited
    case unused
}

private final class SeqnoStubSendService: SendService, @unchecked Sendable {
    private let clock: SeqnoTestClock
    private let advancesAt: TimeInterval
    private let failingReadsAt: Set<TimeInterval>
    private let lock = NSLock()
    private var loads = 0

    var loadCount: Int {
        lock.withLock { loads }
    }

    init(
        clock: SeqnoTestClock,
        advancesAt: TimeInterval,
        failingReadsAt: Set<TimeInterval> = []
    ) {
        self.clock = clock
        self.advancesAt = advancesAt
        self.failingReadsAt = failingReadsAt
    }

    func loadSeqno(wallet _: KeeperCore.Wallet) async throws -> UInt64 {
        let elapsed = clock.elapsed
        lock.withLock { loads += 1 }
        if failingReadsAt.contains(elapsed) {
            throw SeqnoStubError.rateLimited
        }
        return elapsed >= advancesAt ? 1 : 0
    }

    func loadTransactionInfo(
        boc _: String,
        wallet _: KeeperCore.Wallet,
        params _: [EmulateMessageToWalletRequestParamsInner]?,
        currency _: Currency?
    ) async throws -> TonAPI.MessageConsequences {
        throw SeqnoStubError.unused
    }

    func sendTransaction(boc _: String, wallet _: KeeperCore.Wallet, headers _: [String: String]) async throws {
        throw SeqnoStubError.unused
    }

    func sendTransactions(batch _: [String], wallet _: KeeperCore.Wallet) async throws {
        throw SeqnoStubError.unused
    }

    func getTimeoutSafely(wallet _: KeeperCore.Wallet, TTL _: UInt64) async -> UInt64 {
        0
    }

    func getJettonCustomPayload(wallet _: KeeperCore.Wallet, jetton _: Address) async throws -> KeeperCore.JettonTransferPayload {
        throw SeqnoStubError.unused
    }

    func getIndexingLatency(wallet _: KeeperCore.Wallet) async throws -> Int {
        throw SeqnoStubError.unused
    }
}

private extension KeeperCore.Wallet {
    static var seqnoTestWallet: KeeperCore.Wallet {
        KeeperCore.Wallet(
            id: "seqno-waiter-test",
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

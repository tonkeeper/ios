import Foundation
@testable import KeeperCore
import XCTest

final class PendingTransactionsServiceTests: XCTestCase {
    func test_report_sendsImmediatelyAndRetainsNothingOnSuccess() async {
        let writer = PendingTransactionWriterStub()
        let service = makeService(writer: writer)

        await service.report(makeTransaction(txHash: "hash"))
        await service.flushRetained()

        let received = await writer.received
        XCTAssertEqual(received.map(\.txHash), ["hash"])
    }

    func test_report_retainsFailedTransactionAndResendsItOnFlush() async {
        let writer = PendingTransactionWriterStub(outcomes: [.failure, .success])
        let service = makeService(writer: writer)

        await service.report(makeTransaction(txHash: "hash"))
        await service.flushRetained()

        let received = await writer.received
        XCTAssertEqual(received.map(\.txHash), ["hash", "hash"])
    }

    func test_flushRetained_stopsResendingAfterSuccess() async {
        let writer = PendingTransactionWriterStub(outcomes: [.failure, .success])
        let service = makeService(writer: writer)

        await service.report(makeTransaction(txHash: "hash"))
        await service.flushRetained()
        await service.flushRetained()

        let received = await writer.received
        XCTAssertEqual(received.count, 2)
    }

    func test_flushRetained_keepsResendingWhileItKeepsFailing() async {
        let writer = PendingTransactionWriterStub(outcomes: [.failure])
        let service = makeService(writer: writer)

        await service.report(makeTransaction(txHash: "hash"))
        await service.flushRetained()
        await service.flushRetained()

        let received = await writer.received
        XCTAssertEqual(received.count, 3)
    }

    func test_flushRetained_dropsTransactionPastTimeToLiveWithoutSending() async {
        let writer = PendingTransactionWriterStub(outcomes: [.failure])
        let clock = TestClock(date: Date(timeIntervalSince1970: 0))
        let service = makeService(writer: writer, timeToLive: 300, clock: clock)

        await service.report(makeTransaction(txHash: "hash"))
        clock.date = Date(timeIntervalSince1970: 300)
        await service.flushRetained()

        let received = await writer.received
        XCTAssertEqual(received.count, 1)
    }

    func test_flushRetained_doesNotExtendTimeToLiveOfARetriedTransaction() async {
        let writer = PendingTransactionWriterStub(outcomes: [.failure])
        let clock = TestClock(date: Date(timeIntervalSince1970: 0))
        let service = makeService(writer: writer, timeToLive: 300, clock: clock)

        await service.report(makeTransaction(txHash: "hash"))
        clock.date = Date(timeIntervalSince1970: 299)
        await service.flushRetained()
        clock.date = Date(timeIntervalSince1970: 301)
        await service.flushRetained()

        let received = await writer.received
        XCTAssertEqual(received.count, 2)
    }

    func test_report_retainsTheSameTransactionOnlyOnce() async {
        let writer = PendingTransactionWriterStub(outcomes: [.failure])
        let service = makeService(writer: writer)

        await service.report(makeTransaction(txHash: "hash"))
        await service.report(makeTransaction(txHash: "hash"))
        await writer.setOutcomes([.success])
        await service.flushRetained()

        let received = await writer.received
        XCTAssertEqual(received.count, 3)
    }

    func test_flushRetained_concurrentFlushesDoNotResendTheSameTransactionTwice() async {
        let writer = PendingTransactionWriterStub(outcomes: [.failure, .success])
        let service = makeService(writer: writer)

        await service.report(makeTransaction(txHash: "hash"))
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 4 {
                group.addTask { await service.flushRetained() }
            }
        }

        let received = await writer.received
        XCTAssertEqual(received.count, 2)
    }

    func test_report_sendsChainNetworkAndActivityTypeAsGiven() async {
        let writer = PendingTransactionWriterStub()
        let service = makeService(writer: writer)
        let transaction = MultichainPendingTransaction(
            walletId: "wallet",
            chain: .base,
            network: .mainnet,
            txHash: "hash",
            activityType: .swap(
                MultichainPendingTransaction.SwapDetails(
                    fromAssetId: "ton/mainnet/coin",
                    toAssetId: "base/mainnet/coin",
                    quote: .init(aggregator: "swapkit", routeId: "route", providerRouteId: "provider-route")
                )
            )
        )

        await service.report(transaction)

        let received = await writer.received
        XCTAssertEqual(received, [transaction])
    }
}

private extension PendingTransactionsServiceTests {
    func makeService(
        writer: MultichainPendingTransactionWriter,
        timeToLive: TimeInterval = 300,
        clock: TestClock = TestClock(date: Date(timeIntervalSince1970: 0))
    ) -> PendingTransactionsServiceImplementation {
        PendingTransactionsServiceImplementation(
            writer: writer,
            timeToLive: timeToLive,
            now: { clock.date }
        )
    }

    func makeTransaction(txHash: String) -> MultichainPendingTransaction {
        MultichainPendingTransaction(
            walletId: "wallet",
            chain: .eth,
            network: .mainnet,
            txHash: txHash,
            activityType: .send
        )
    }
}

private final class TestClock: @unchecked Sendable {
    var date: Date

    init(date: Date) {
        self.date = date
    }
}

/// Outcomes are consumed in order; the last one keeps repeating.
private actor PendingTransactionWriterStub: MultichainPendingTransactionWriter {
    enum Outcome {
        case success
        case failure
    }

    private(set) var received = [MultichainPendingTransaction]()
    private var outcomes: [Outcome]

    init(outcomes: [Outcome] = [.success]) {
        self.outcomes = outcomes
    }

    func setOutcomes(_ outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func addPendingTransaction(
        _ transaction: MultichainPendingTransaction
    ) async throws(MultichainClientAPIError) {
        received.append(transaction)
        switch nextOutcome() {
        case .success:
            return
        case .failure:
            throw .connectionError(underlying: nil)
        }
    }

    private func nextOutcome() -> Outcome {
        if outcomes.count > 1 {
            return outcomes.removeFirst()
        }
        return outcomes.first ?? .success
    }
}

@testable import App
import Combine
@testable import KeeperCore
@testable import Perps
import PerpsModels
import XCTest

@MainActor
final class PerpsTradeConfirmViewModelTests: XCTestCase {
    /// The observer is registered once for the view model's lifetime; appear
    /// cycles only balance the price interest. A second cycle used to stack a
    /// duplicate observer, doubling every rows refresh.
    func test_appearCycles_keepSinglePricesObserver() async throws {
        let store = PerpsMarketsStore.makeForTests()
        let session = FakePerpsTradingService.makeReviewingSizeChangeSession()
        let viewModel = try XCTUnwrap(PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: 2,
            format: PerpsFormatting.live,
            marketsStore: store
        ))

        viewModel.onAppear()
        viewModel.onDisappear()
        viewModel.onAppear()

        // Let the interest churn from the appear cycles settle before counting.
        try await Task.sleep(nanoseconds: 300_000_000)

        var refreshes = 0
        let watching = viewModel.$rows.dropFirst().sink { _ in refreshes += 1 }
        store.sendEvent(.didUpdate(store.getState()))
        try await Task.sleep(nanoseconds: 500_000_000)
        withExtendedLifetime(watching) {}

        XCTAssertEqual(refreshes, 1, "one prices event must refresh the confirm rows exactly once")
        viewModel.onDisappear()
    }

    func test_closeConfirm_staleReviewIsReplannedOnAPriceTick() async {
        let client = FakeMarkPricesClient()
        let viewModel = makeCloseConfirm(
            store: .makeForTests(tickers: [1: "BTC/USD"], client: client),
            reviewLifetime: 0
        )
        viewModel.onAppear()
        viewModel.onRefreshReview = { [weak viewModel] in
            viewModel?.updateCloseReview(FakePerpsTradingService.makeCloseReview(estimatedPnlUsd: -1.2))
        }

        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67000")])
        await waitUntil { viewModel.rows.first { $0.id == .pnl }?.value == PerpsFormatting.live.signedUsd(-1.2) }

        XCTAssertEqual(viewModel.rows.first { $0.id == .pnl }?.value, PerpsFormatting.live.signedUsd(-1.2))
        XCTAssertEqual(viewModel.rows.first { $0.id == .pnl }?.tone, .negative)
        viewModel.onDisappear()
    }

    func test_closeConfirm_isNotReplannedWhileFreshOrOnceConfirmed() async throws {
        let client = FakeMarkPricesClient()
        let store = PerpsMarketsStore.makeForTests(tickers: [1: "BTC/USD"], client: client)
        var refreshes = 0
        let fresh = makeCloseConfirm(store: store)
        fresh.onRefreshReview = { refreshes += 1 }
        let confirmed = makeCloseConfirm(store: store, reviewLifetime: 0)
        confirmed.onRefreshReview = { refreshes += 1 }
        confirmed.confirm()

        fresh.onAppear()
        confirmed.onAppear()
        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67000")])
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(refreshes, 0)
        fresh.onDisappear()
        confirmed.onDisappear()
    }

    func test_openConfirm_announcesALevelThePriceHasCrossed_oncePerChange() async throws {
        let client = FakeMarkPricesClient()
        let viewModel = PerpsTradeConfirmViewModel(
            context: FakePerpsTradingService.makeConfirmContext(intent: FakePerpsTradingService.makeIntent(
                autoClose: PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000), stopLoss: nil)
            )),
            format: PerpsFormatting.live,
            marketsStore: PerpsMarketsStore.makeForTests(tickers: [1: "BTC/USD"], client: client)
        )
        var announced: [PerpsAutoCloseValidation.ConfirmStaleKind] = []
        viewModel.onAutoCloseStale = { announced.append($0) }
        viewModel.onAppear()
        await waitForTickers(client, toEqual: ["BTC/USD"])

        await client.emit([("BTC/USD", "71000")])
        await waitUntil { !announced.isEmpty }
        await client.emit([("BTC/USD", "71500")])
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(announced, [.takeProfit])
        viewModel.onDisappear()
    }

    func test_sizeChangeConfirm_doesNotAnnounceALevelTheUserIsNotChanging() async throws {
        let client = FakeMarkPricesClient()
        let session = FakePerpsTradingService.makeReviewingSizeChangeSession(
            autoClose: PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000), stopLoss: nil)
        )
        let viewModel = try XCTUnwrap(PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: 2,
            format: PerpsFormatting.live,
            marketsStore: PerpsMarketsStore.makeForTests(tickers: [1: "BTC/USD"], client: client)
        ))
        var announced: [PerpsAutoCloseValidation.ConfirmStaleKind] = []
        viewModel.onAutoCloseStale = { announced.append($0) }
        viewModel.onAppear()
        await waitForTickers(client, toEqual: ["BTC/USD"])

        await client.emit([("BTC/USD", "71000")])
        await waitUntil { viewModel.rows.first { $0.id == .autoClose }?.valueParts?.first?.tone == .negative }

        XCTAssertEqual(viewModel.rows.first { $0.id == .autoClose }?.valueParts?.first?.tone, .negative)
        XCTAssertTrue(announced.isEmpty)
        viewModel.onDisappear()
    }

    func test_openConfirm_dropsAReviewForAnIntentTheUserHasSinceEdited() throws {
        let context = FakePerpsTradingService.makeConfirmContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: PerpsFormatting.live)
        viewModel.updateOpenAutoClose(PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000), stopLoss: nil))

        viewModel.updateOpenReview(FakePerpsTradingService.makeReview(entryPrice: 67000), for: context.intent)
        XCTAssertEqual(viewModel.rows.first { $0.id == .entry }?.value, PerpsFormatting.live.usd(66541.70))

        let current = try XCTUnwrap(viewModel.openConfirmContext?.intent)
        viewModel.updateOpenReview(FakePerpsTradingService.makeReview(entryPrice: 67000), for: current)
        XCTAssertEqual(viewModel.rows.first { $0.id == .entry }?.value, PerpsFormatting.live.usd(67000))
    }

    func test_sizeChangeConfirm_aRefreshFinishingAfterConfirmChangesNothing() throws {
        let session = FakePerpsTradingService.makeReviewingSizeChangeSession()
        let viewModel = try XCTUnwrap(PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: 2,
            format: PerpsFormatting.live
        ))
        let prepared = try XCTUnwrap(session.prepared)
        let shownEntry = viewModel.rows.first { $0.id == .entry }?.value
        viewModel.onConfirm = { _ = session.beginConfirming() }

        viewModel.confirm()
        session.refreshReview(
            FakePerpsTradingService.makeSizeChangeReview(entryPrice: PerpsValueChange(old: 66541.70, new: 67000)),
            operationId: prepared.operationId
        )

        XCTAssertFalse(viewModel.isConfirmationEnabled)
        XCTAssertEqual(viewModel.rows.first { $0.id == .entry }?.value, shownEntry)

        session.cancelConfirming()

        XCTAssertTrue(viewModel.isConfirmationEnabled)
    }

    private func makeCloseConfirm(
        store: PerpsMarketsStore,
        reviewLifetime: TimeInterval = 5
    ) -> PerpsTradeConfirmViewModel {
        let viewModel = PerpsTradeConfirmViewModel(
            closeContext: PerpsCloseConfirmContext(
                marketId: 1,
                sizeDecimals: 5,
                review: FakePerpsTradingService.makeCloseReview()
            ),
            format: PerpsFormatting.live,
            marketsStore: store
        )
        viewModel.reviewLifetime = reviewLifetime
        return viewModel
    }

    private func waitUntil(timeout: TimeInterval = 2, condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

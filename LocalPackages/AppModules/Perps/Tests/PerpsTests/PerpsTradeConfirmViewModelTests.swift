import Combine
@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

@MainActor
final class PerpsTradeConfirmViewModelTests: XCTestCase {
    func testDollarRowsDoNotRepeatTheirValueInStablecoins() {
        let review = PerpsCloseReview(
            symbol: "BTC", side: .long, leverage: 10, marginUsd: 100,
            notionalUsd: 1000, baseSize: 10, estimatedFeeUsd: 0.01789, feeRatePercent: 0.095,
            estimatedPnlUsd: 2, estimatedReceiveUsd: 101.98
        )
        let rows = PerpsTradeConfirmViewModel.makeCloseRows(review: review, sizeDecimals: 6, format: .test)
        for id in [PerpsTradeConfirmRow.Kind.position, .youReceive, .fee] {
            XCTAssertNotNil(rows.first { $0.id == id })
            XCTAssertNil(rows.first { $0.id == id }?.subValue)
        }
        XCTAssertNotNil(rows.first { $0.id == .size }?.subValue)
    }

    func testFeeRowShowsTheRateWhileYouPayKeepsTheFeeInDollars() {
        let review = PerpsCloseReview(
            symbol: "BTC", side: .long, leverage: 10, marginUsd: 100,
            notionalUsd: 1000, baseSize: 10, estimatedFeeUsd: 0.95, feeRatePercent: 0.095,
            estimatedPnlUsd: 2, estimatedReceiveUsd: 101.05
        )
        let close = PerpsTradeConfirmViewModel.makeCloseRows(review: review, sizeDecimals: 6, format: .test)
        XCTAssertEqual(close.first { $0.id == .fee }?.value, "0.095%")

        let unrated = PerpsTradeConfirmViewModel.makeCloseRows(
            review: PerpsCloseReview(
                symbol: "BTC", side: .long, leverage: 10, marginUsd: 100, notionalUsd: 1000, baseSize: 10,
                estimatedFeeUsd: 0.95, feeRatePercent: nil, estimatedPnlUsd: 2, estimatedReceiveUsd: 101.05
            ),
            sizeDecimals: 6,
            format: .test
        )
        XCTAssertEqual(unrated.first { $0.id == .fee }?.value, TKLocales.Perps.Confirm.unavailable)

        let open = PerpsTradeConfirmViewModel(
            context: makeContext(estimatedFeeUsd: 0.95, feeRatePercent: 0.095),
            format: .test
        ).rows
        XCTAssertEqual(open.first { $0.id == .fee }?.value, "0.095%")
        XCTAssertEqual(open.first { $0.id == .youPay }?.value, PerpsFormatting.test.usd(100.95))
    }

    func testFundingFeeKeepsTokenEquivalentOnlyForNonDollarAssets() {
        for symbol in ["USD", "USDC", "ETH"] {
            let row = PerpsFundingConfirmRows.networkFee(title: "", fee: "0.01", symbol: symbol, usd: 0.01, format: .test)
            XCTAssertEqual(row.subValue == nil, symbol != "ETH")
        }
        let unpriced = PerpsFundingConfirmRows.networkFee(title: "", fee: "0.01", symbol: "USDC", usd: nil, format: .test)
        XCTAssertTrue(unpriced.value.contains("USDC"))
    }

    func test_autoClosePreviewFailure_usesExistingReview() async throws {
        let context = makeContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test)
        for error in [PerpsTradingError.offline, .invalidAmount] {
            let editing = await viewModel.autoCloseEditingContext { intent in
                XCTAssertNil(intent.autoClose)
                return .failure(error)
            }
            XCTAssertEqual(try XCTUnwrap(editing).review, context.review)
            XCTAssertEqual(editing?.intent, context.intent)
        }
        XCTAssertEqual(viewModel.openConfirmContext?.review, context.review)
    }

    func test_autoClosePreviewSuccess_doesNotChangeTheDisplayedReview() async throws {
        let context = makeContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test)
        let values = viewModel.rows.map(\.value)
        let refreshed = makeContext(entryPrice: 120).review
        let editing = await viewModel.autoCloseEditingContext { _ in .success(refreshed) }
        XCTAssertEqual(try XCTUnwrap(editing).review, refreshed)
        XCTAssertEqual(viewModel.openConfirmContext?.review, context.review)
        XCTAssertEqual(viewModel.rows.map(\.value), values)

        viewModel.updateOpenAutoClose(editing?.intent.autoClose, review: editing?.review)
        XCTAssertEqual(viewModel.openConfirmContext?.review, refreshed)
    }

    func test_editAutoClose_blocksOverlappingRequestsAndConfirmation_thenAllowsRetry() async {
        let viewModel = PerpsTradeConfirmViewModel(context: makeContext(), format: .test)
        let started = expectation(description: "preview started")
        let finished = expectation(description: "preview finished")
        var continuation: CheckedContinuation<Void, Never>?
        var edits = 0
        var confirmations = 0
        viewModel.onConfirm = { confirmations += 1 }
        viewModel.onEditAutoClose = {
            edits += 1
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
            finished.fulfill()
        }
        viewModel.editAutoClose()
        viewModel.editAutoClose()
        await fulfillment(of: [started], timeout: 1)
        viewModel.editAutoClose()
        viewModel.confirm()
        XCTAssertEqual(edits, 1)
        XCTAssertEqual(confirmations, 0)
        continuation?.resume()
        await fulfillment(of: [finished], timeout: 1)

        let retried = expectation(description: "preview retried")
        viewModel.onEditAutoClose = {
            edits += 1
            retried.fulfill()
        }
        viewModel.editAutoClose()
        await fulfillment(of: [retried], timeout: 1)
        XCTAssertEqual(edits, 2)
    }

    func test_autoClosePreview_discardsAResultAfterTheIntentChanges() async {
        let viewModel = PerpsTradeConfirmViewModel(context: makeContext(), format: .test)
        let editing = await viewModel.autoCloseEditingContext { _ in
            viewModel.updateOpenAutoClose(nil)
            return .success(self.makeContext(entryPrice: 120).review)
        }
        XCTAssertNil(editing)
        XCTAssertEqual(viewModel.openConfirmContext?.review, makeContext().review)
    }

    func test_leavingConfirm_discardsThePendingPreview() async {
        let viewModel = PerpsTradeConfirmViewModel(context: makeContext(), format: .test)
        let started = expectation(description: "preview started")
        let finished = expectation(description: "cancelled preview finished")
        var continuation: CheckedContinuation<PerpsOpenOrderReview, Never>?
        viewModel.onEditAutoClose = {
            let editing = await viewModel.autoCloseEditingContext { _ in
                .success(await withCheckedContinuation {
                    continuation = $0
                    started.fulfill()
                })
            }
            XCTAssertNil(editing)
            finished.fulfill()
        }
        viewModel.editAutoClose()
        await fulfillment(of: [started], timeout: 1)
        viewModel.back()
        continuation?.resume(returning: makeContext(entryPrice: 120).review)
        await fulfillment(of: [finished], timeout: 1)

        let retried = expectation(description: "edit after returning")
        viewModel.onEditAutoClose = { retried.fulfill() }
        viewModel.editAutoClose()
        await fulfillment(of: [retried], timeout: 1)
    }

    func test_updateOpenAutoClose_carriesOnlyTheROITypedForTheLegsItKeeps() {
        let viewModel = PerpsTradeConfirmViewModel(context: makeContext(), format: .test)
        let both = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 102),
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 99)
        )
        viewModel.updateOpenAutoClose(both, roiInput: PerpsAutoCloseROIInput(
            takeProfit: PerpsAutoCloseROI(sign: .plus, text: "20"),
            stopLoss: PerpsAutoCloseROI(sign: .minus, text: "10")
        ))
        XCTAssertEqual(viewModel.openConfirmContext?.intent.takeProfitROIPercent, 20)
        XCTAssertEqual(viewModel.openConfirmContext?.intent.stopLossROIPercent, -10)

        viewModel.updateOpenAutoClose(both, roiInput: PerpsAutoCloseROIInput(
            stopLoss: PerpsAutoCloseROI(sign: .minus, text: "10")
        ))
        XCTAssertNil(viewModel.openConfirmContext?.intent.takeProfitROIPercent, "a leg switched to a price loses its ROI")
        XCTAssertEqual(viewModel.openConfirmContext?.intent.stopLossROIPercent, -10)

        viewModel.updateOpenAutoClose(both, roiInput: PerpsAutoCloseROIInput(
            takeProfit: PerpsAutoCloseROI(sign: .plus, text: "20"),
            stopLoss: PerpsAutoCloseROI(sign: .minus, text: "10")
        ))
        let remaining = PerpsAutoClose(takeProfit: both.takeProfit, stopLoss: nil)
        viewModel.updateOpenAutoClose(remaining)
        let stale = viewModel.openConfirmContext?.replacingAutoClose(remaining)
        for intent in [viewModel.openConfirmContext?.intent, stale?.intent] {
            XCTAssertEqual(intent?.takeProfitROIPercent, 20, "continuing without a stale leg keeps the other's ROI")
            XCTAssertNil(intent?.stopLossROIPercent)
        }
    }

    func test_loyaltyReward_followsTheTradeSize_hidesAnOtherSizesRewardOnFailure_andRetries() async {
        let context = makeContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test)
        viewModel.loyaltyRewardInterval = 0
        var asked = [Double]()
        viewModel.loyaltyReward = { volume in
            asked.append(volume)
            switch volume {
            case 1000: return "100"
            case 900:
                if asked.filter({ $0 == 900 }).count == 1 { throw PerpsTradingError.offline }
                return "90"
            default: return nil
            }
        }
        await rewardRow(of: viewModel, is: "+100")

        viewModel.updateOpenReview(review(notionalUsd: 900), for: context.intent)
        await rewardRow(of: viewModel, is: "+90")
        XCTAssertEqual(asked, [1000, 900, 900])

        viewModel.updateOpenReview(review(notionalUsd: 50), for: context.intent)
        await rewardRow(of: viewModel, is: nil)
    }

    func test_loyaltyReward_failureHidesTheRewardOfTheOldSize() async {
        let context = makeContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test)
        viewModel.loyaltyRewardInterval = 60
        viewModel.loyaltyReward = { volume in
            guard volume == 1000 else { throw PerpsTradingError.offline }
            return "100"
        }
        await rewardRow(of: viewModel, is: "+100")
        viewModel.loyaltyRewardInterval = 0.3
        viewModel.updateOpenReview(review(notionalUsd: 900), for: context.intent)
        await rewardRow(of: viewModel, is: nil)
    }

    func test_loyaltyReward_aSubCentRequoteKeepsTheRewardWithoutAskingAgain() async {
        let context = makeContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test)
        viewModel.loyaltyRewardInterval = 0
        var asked = [Double]()
        viewModel.loyaltyReward = { volume in
            asked.append(volume)
            return "54"
        }
        viewModel.updateOpenReview(review(notionalUsd: 540.004), for: context.intent)
        await rewardRow(of: viewModel, is: "+54")
        viewModel.updateOpenReview(review(notionalUsd: 540.009), for: context.intent)
        await Task.yield()
        XCTAssertEqual(asked.last, 540)
        XCTAssertEqual(asked.filter { $0 == 540 }.count, 1)
    }

    func test_loyaltyReward_anOpenAwaitingItsReviewAsksOnlyForTheRefreshedSize() async {
        let context = makeContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test)
        viewModel.loyaltyRewardInterval = 60
        var asked = [Double]()
        viewModel.loyaltyReward = { volume in
            asked.append(volume)
            return "90"
        }
        viewModel.awaitReview()
        viewModel.updateOpenReview(review(notionalUsd: 900), for: context.intent)
        await rewardRow(of: viewModel, is: "+90")
        XCTAssertEqual(asked, [900])
    }

    private func rewardRow(of viewModel: PerpsTradeConfirmViewModel, is value: String?) async {
        let matched = expectation(description: "reward row \(value ?? "hidden")")
        let cancellable = viewModel.$rows
            .map { $0.first { $0.id == .loyaltyReward }?.value }
            .filter { $0 == value }
            .first()
            .sink { _ in matched.fulfill() }
        await fulfillment(of: [matched], timeout: 1)
        withExtendedLifetime(cancellable) {}
    }

    private func review(notionalUsd: Double) -> PerpsOpenOrderReview {
        PerpsOpenOrderReview(
            symbol: "BTC", marginUsd: 100, entryPrice: 100, liquidationPrice: nil,
            notionalUsd: notionalUsd, baseSize: notionalUsd / 100,
            estimatedFeeUsd: nil, feeRatePercent: nil, liquidationUnavailableReason: nil
        )
    }

    func test_anOpenAwaitingItsReviewReadsItOnAppearAndHoldsTheSwipeUntilItLands() async {
        let context = makeContext()
        let refreshed = makeContext(entryPrice: 120).review
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test, marketsStore: StubRootMarketsStore())
        let read = expectation(description: "review read on appear")
        var confirmations = 0
        var staleAnnounced: [PerpsAutoCloseValidation.ConfirmStaleKind] = []
        viewModel.onConfirm = { confirmations += 1 }
        viewModel.onAutoCloseStale = { staleAnnounced.append($0) }
        viewModel.onRefreshReview = { [weak viewModel] in
            viewModel?.updateOpenReview(refreshed, for: context.intent)
            read.fulfill()
        }

        viewModel.awaitReview()
        viewModel.confirm()
        XCTAssertEqual(confirmations, 0)
        XCTAssertTrue(viewModel.isProcessing)

        viewModel.onAppear()
        await fulfillment(of: [read], timeout: 1)
        XCTAssertEqual(viewModel.openConfirmContext?.review, refreshed)
        XCTAssertTrue(viewModel.isConfirmationEnabled)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(staleAnnounced, [.takeProfit], "the take-profit at 101 is behind the new entry at 120")
        viewModel.confirm()
        XCTAssertEqual(confirmations, 1)
    }

    func test_anOpenAwaitingItsReviewKeepsTheSwipeHeldWhenTheReadFails() async {
        let context = makeContext()
        let viewModel = PerpsTradeConfirmViewModel(context: context, format: .test, marketsStore: StubRootMarketsStore())
        let read = expectation(description: "review read on appear")
        var confirmations = 0
        viewModel.onConfirm = { confirmations += 1 }
        viewModel.onRefreshReview = { read.fulfill() }

        viewModel.awaitReview()
        viewModel.onAppear()
        await fulfillment(of: [read], timeout: 1)
        viewModel.confirm()

        XCTAssertEqual(viewModel.openConfirmContext?.review, context.review)
        XCTAssertFalse(viewModel.isConfirmationEnabled)
        XCTAssertTrue(viewModel.isProcessing)
        XCTAssertEqual(confirmations, 0)
    }

    private func makeContext(
        entryPrice: Double = 100,
        estimatedFeeUsd: Double? = nil,
        feeRatePercent: Double? = nil
    ) -> PerpsConfirmContext {
        PerpsConfirmContext(
            intent: PerpsOpenMarketIntent(
                marketId: 1, side: .long, marginUsd: "100", leverage: 10, maxSlippage: 0.01,
                autoClose: PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 101), stopLoss: nil)
            ),
            sizeDecimals: 6, priceDecimals: 2,
            review: PerpsOpenOrderReview(
                symbol: "BTC", marginUsd: 100, entryPrice: entryPrice, liquidationPrice: nil,
                notionalUsd: 1000, baseSize: 1000 / entryPrice,
                estimatedFeeUsd: estimatedFeeUsd, feeRatePercent: feeRatePercent, liquidationUnavailableReason: nil
            )
        )
    }
}

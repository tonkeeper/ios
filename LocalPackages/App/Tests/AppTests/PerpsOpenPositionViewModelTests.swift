@testable import App
import ChainKit
import Combine
@testable import KeeperCore
@testable import Perps
import PerpsModels
import TKLocalize
import TonSwift
import XCTest

@MainActor
final class PerpsOpenPositionViewModelTests: XCTestCase {
    private func makeViewModel(
        side: PerpsTradeSide = .long,
        service: FakePerpsTradingService = FakePerpsTradingService(),
        status: PerpsAccountStatus = .account(accountIndex: 1),
        balance: String = "712.56",
        marketsStore: PerpsMarketsStore = .makeForTests()
    ) -> PerpsOpenPositionViewModel {
        let reader = AccountReadingSpy()
        reader.statusResult = status
        reader.portfolioResult = PerpsAccountSnapshot(availableBalance: balance)
        let store = PerpsAccountStore(service: reader, wallet: .openPositionTest())
        return PerpsOpenPositionViewModel(
            marketId: 1,
            side: side,
            service: service,
            accountStore: store,
            marketsStore: marketsStore,
            initialLeverage: 10,
            format: PerpsFormatting.live
        )
    }

    // MARK: - Pure logic (no load)

    func test_amountSanitization_stripsLettersAndExtraDots() {
        let viewModel = makeViewModel()
        viewModel.setAmount("1a2.3.4")
        XCTAssertEqual(viewModel.amountText, "12.34")
    }

    func test_size_isMarginTimesLeverage() {
        let viewModel = makeViewModel()
        viewModel.applyLeverage(27)
        viewModel.setAmount("20")
        XCTAssertEqual(viewModel.sizeUsd, 540, accuracy: 1e-6)
    }

    func test_applyAutoClose_emptyBecomesNil() {
        let viewModel = makeViewModel()
        viewModel.applyAutoClose(PerpsAutoClose(takeProfit: nil, stopLoss: nil))
        XCTAssertNil(viewModel.autoCloseSummary)
        viewModel.applyAutoClose(PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000), stopLoss: nil))
        XCTAssertNotNil(viewModel.autoCloseSummary)
    }

    func test_applyAutoClose_invalidValueIsRejectedWithWarning() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready }
        viewModel.applyAutoClose(PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 60000), stopLoss: nil))
        XCTAssertNil(viewModel.autoCloseSummary)
        XCTAssertEqual(viewModel.state.autoCloseWarningText, "The Take Profit value must be above the current price.")
    }

    // MARK: - State machine

    func test_load_reachesReady_seedsDefaultLeverage_andBalance() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        XCTAssertEqual(viewModel.leverage, 27)
        XCTAssertEqual(viewModel.balanceText, PerpsFormatting.live.usd(712.56))
    }

    func test_marketLoadFailure_invokesOnLoadFailed_andStaysLoading() async {
        let service = FakePerpsTradingService()
        service.failsMarketLoad = true
        let viewModel = makeViewModel(service: service)
        let failed = XCTestExpectation(description: "load failed")
        viewModel.onLoadFailed = { failed.fulfill() }
        viewModel.onAppear()
        await fulfillment(of: [failed], timeout: 5)
        XCTAssertEqual(viewModel.viewState, .loading)
        XCTAssertFalse(viewModel.isReviewEnabled)
    }

    // MARK: - Account / availability

    func test_needsDeposit_showsDeposit_andBlocksReview() async {
        let viewModel = makeViewModel(status: .noAccount(ethAddress: "0x0"))
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && viewModel.account == .needsDeposit(balance: nil) }
        viewModel.setAmount("20")
        XCTAssertTrue(viewModel.canDeposit)
        XCTAssertEqual(viewModel.balanceErrorText, TKLocales.Perps.OpenPosition.insufficientFunds)
        XCTAssertFalse(viewModel.isReviewEnabled)
    }

    func test_max_fillsAvailableBalance() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { accountIsReady(viewModel) }
        viewModel.setMax()
        XCTAssertEqual(viewModel.marginUsd, 712.56, accuracy: 1e-6)
    }

    func test_orderRetriesBalanceAfterInitialAccountReadFailure() async {
        let reader = AccountReadingSpy()
        reader.statusResult = .unavailable(reason: "offline")
        let store = PerpsAccountStore(service: reader, wallet: .openPositionTest())

        let settled = XCTestExpectation(description: "failed resolve settled")
        settled.assertForOverFulfill = false
        store.addObserver(self) { _, event in
            if case let .didUpdate(state) = event, case .unresolved = state {
                settled.fulfill()
            }
        }
        store.resolveIfNeeded()
        await fulfillment(of: [settled], timeout: 5)
        XCTAssertEqual(reader.portfolioCallCount, 0)

        reader.statusResult = .account(accountIndex: 1)
        reader.portfolioResult = PerpsAccountSnapshot(availableBalance: "321.45")
        let viewModel = PerpsOpenPositionViewModel(
            marketId: 1,
            side: .long,
            service: FakePerpsTradingService(),
            accountStore: store,
            marketsStore: PerpsMarketsStore.makeForTests(),
            initialLeverage: 10,
            format: PerpsFormatting.live
        )

        viewModel.onAppear()

        await waitUntil(viewModel) {
            guard viewModel.viewState == .ready,
                  case let .ready(balance) = viewModel.account
            else {
                return false
            }
            return abs(balance - 321.45) < 1e-6
        }
        XCTAssertEqual(reader.portfolioCallCount, 1)
        XCTAssertEqual(viewModel.balanceText, PerpsFormatting.live.usd(321.45))
    }

    // MARK: - Review gating

    func test_theMinimumMarginIsThePlannersButAtLeastOneDollar() async {
        let service = FakePerpsTradingService()
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("0.99")
        XCTAssertEqual(viewModel.balanceErrorText, TKLocales.Perps.OpenPosition.minimumMargin(PerpsFormatting.live.usd(1)))
        XCTAssertFalse(viewModel.isReviewEnabled)
        viewModel.setAmount("1")
        XCTAssertNil(viewModel.balanceErrorText)
        XCTAssertTrue(viewModel.isReviewEnabled)

        service.reviewer.minimumOpenMargin = 3.340668
        viewModel.setAmount("3.34")
        let named = TKLocales.Perps.OpenPosition.minimumMargin(PerpsFormatting.live.usd(3.35))
        await waitUntil(viewModel) { viewModel.balanceErrorText == named }
        XCTAssertFalse(viewModel.isReviewEnabled)
        viewModel.setAmount("3.35")
        XCTAssertNil(viewModel.balanceErrorText)
        XCTAssertTrue(viewModel.isReviewEnabled)

        service.previewResult = .failure(.invalidAmount)
        viewModel.review()
        await waitUntil(viewModel) { viewModel.state.reviewWarningText != nil }
        XCTAssertEqual(viewModel.state.reviewWarningText, TKLocales.Perps.Error.invalidAmount)
    }

    func test_aRefusedReview_reloadsTheMinimum_andTheBalanceLineNamesIt() async {
        let service = FakePerpsTradingService()
        service.reviewer.minimumOpenMargin = 3.340668
        service.previewResult = .failure(.invalidAmount)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("3.35")
        await waitUntil(viewModel) { service.reviewerLoads > 0 && viewModel.isReviewEnabled }

        let loads = service.reviewerLoads
        let fresher = FakePerpetualReviewer()
        fresher.minimumOpenMargin = 3.5
        service.reviewer = fresher
        viewModel.review()

        await waitUntil(viewModel) { !viewModel.isReviewInFlight && service.reviewerLoads > loads }
        XCTAssertNil(viewModel.state.reviewWarningText)
        XCTAssertEqual(viewModel.balanceErrorText, TKLocales.Perps.OpenPosition.minimumMargin(PerpsFormatting.live.usd(3.5)))
        XCTAssertFalse(viewModel.isReviewEnabled)
    }

    func test_reviewerProbe_clearsTheMarketMinimumAfterTheSizeStepFloor() async throws {
        let service = FakePerpsTradingService()
        service.context = FakePerpsTradingService.makeContext(minNotionalUsd: 10)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        await waitUntil(viewModel) { !service.reviewerIntents.isEmpty }

        let context = try XCTUnwrap(service.context)
        let probe = try XCTUnwrap(service.reviewerIntents.first)
        let margin = try XCTUnwrap(Double(probe.marginUsd))
        let step = pow(10.0, Double(context.sizeDecimals))
        let steppedBase = (margin * probe.leverage / context.displayPrice * step).rounded(.down) / step

        XCTAssertGreaterThanOrEqual(steppedBase, context.minBaseSize)
        XCTAssertGreaterThanOrEqual(steppedBase * context.displayPrice, context.minNotionalUsd)
    }

    func test_noPrice_blocksReview() async {
        // Neither mark nor last-trade is known (displayPrice 0): we can't size the order, so
        // Review is disabled and the header shows "—". Regression for the `Price —` screenshot.
        let service = FakePerpsTradingService()
        service.context = FakePerpsTradingService.makeContext(displayPrice: 0)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("500")
        XCTAssertEqual(viewModel.headerPriceText, "—")
        XCTAssertFalse(viewModel.isReviewEnabled)
    }

    func test_marginAboveTheBalance_showsInsufficientFundsAndBlocksReview() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }

        viewModel.setAmount("713")
        XCTAssertEqual(viewModel.balanceErrorText, TKLocales.Perps.OpenPosition.insufficientFunds)
        XCTAssertFalse(viewModel.isReviewEnabled)

        viewModel.setMax()
        XCTAssertNil(viewModel.balanceErrorText)
        XCTAssertTrue(viewModel.isReviewEnabled)
    }

    func test_max_withSubCentBalance_staysWithinBalance() async {
        let viewModel = makeViewModel(balance: "10.076543")
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }

        viewModel.balanceRow?.onMax()

        XCTAssertEqual(viewModel.amountText, "10.07")
        XCTAssertNil(viewModel.balanceRow?.errorText)
        XCTAssertTrue(viewModel.isReviewEnabled)
    }

    func test_review_emitsConfirmContext_withoutPreparing() async {
        let service = FakePerpsTradingService()
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyLeverage(27)
        viewModel.setAmount("20")

        let reviewed = XCTestExpectation(description: "review emitted")
        var received: PerpsConfirmContext?
        viewModel.onReview = { received = $0; reviewed.fulfill() }
        viewModel.review()

        await fulfillment(of: [reviewed], timeout: 5)
        XCTAssertEqual(received?.intent.marginUsd, "20")
        XCTAssertEqual(received?.intent.leverage, 27)
        XCTAssertEqual(received?.review.entryPrice, 66541.70)
        XCTAssertEqual(service.previewedIntents.first?.marginUsd, "20")
        XCTAssertTrue(service.preparedIntents.isEmpty)
    }

    func test_review_doesNotPrepareASignedTrade() async {
        let service = FakePerpsTradingService()
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")

        let reviewed = XCTestExpectation(description: "review emitted")
        viewModel.onReview = { _ in reviewed.fulfill() }
        viewModel.review()

        await fulfillment(of: [reviewed], timeout: 5)
        XCTAssertTrue(service.preparedIntents.isEmpty)
    }

    func test_review_activatesTheAccountBeforePreviewing() async {
        let service = FakePerpsTradingService()
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")

        var previewsBeforeActivation: Int?
        viewModel.ensureAccountReady = {
            previewsBeforeActivation = service.previewedIntents.count
            return true
        }
        let reviewed = XCTestExpectation(description: "review emitted")
        viewModel.onReview = { _ in reviewed.fulfill() }
        viewModel.review()

        await fulfillment(of: [reviewed], timeout: 5)
        XCTAssertEqual(previewsBeforeActivation, 0)
        XCTAssertEqual(service.previewedIntents.count, 1)
    }

    func test_review_withActivationDeclined_staysOnTheFormWithoutPreviewOrWarning() async {
        let service = FakePerpsTradingService()
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")

        var openedConfirm = false
        viewModel.ensureAccountReady = { false }
        viewModel.onReview = { _ in openedConfirm = true }
        viewModel.review()

        await waitUntil(viewModel) { !viewModel.isReviewInFlight }
        XCTAssertFalse(openedConfirm)
        XCTAssertTrue(service.previewedIntents.isEmpty)
        XCTAssertNil(viewModel.warningText)
        XCTAssertTrue(viewModel.amountFocusState.isActive)
        XCTAssertTrue(viewModel.isReviewEnabled)
    }

    func test_reviewPreviewFailure_showsWarningAndDoesNotOpenConfirm() async {
        let service = FakePerpsTradingService()
        service.previewResult = .failure(.insufficientLiquidity)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyLeverage(27)
        viewModel.setAmount("20")

        var openedConfirm = false
        viewModel.onReview = { _ in openedConfirm = true }
        viewModel.review()

        await waitUntil(viewModel) { viewModel.warningText != nil }
        XCTAssertFalse(openedConfirm)
        XCTAssertEqual(viewModel.warningText, "Not enough market liquidity to fill this size.")
        XCTAssertTrue(viewModel.amountFocusState.isActive)

        // Regaining focus makes the text field commit its buffer back through the
        // binding; that write must not be mistaken for the user editing the amount.
        viewModel.setAmount(viewModel.amountText)
        XCTAssertEqual(viewModel.warningText, "Not enough market liquidity to fill this size.")

        viewModel.setAmount("21")
        XCTAssertNil(viewModel.warningText)
    }

    func test_reviewRefusedForOneAutoCloseLeg_raisesThatLegsAlert_andContinuingDropsOnlyIt() async throws {
        let service = FakePerpsTradingService()
        service.previewResult = .failure(.invalidAutoClose(.takeProfit))
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")
        viewModel.applyAutoClose(PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 65000)
        ))

        let alerted = XCTestExpectation(description: "auto close alert")
        var refused: PerpsAutoCloseValidation.InvalidLegs?
        viewModel.onInvalidAutoClose = { refused = $0; alerted.fulfill() }
        viewModel.review()
        await fulfillment(of: [alerted], timeout: 5)

        XCTAssertEqual(refused, PerpsAutoCloseValidation.InvalidLegs(takeProfit: true, stopLoss: false))
        XCTAssertEqual(viewModel.warningText, "Take Profit needs an update")

        service.previewResult = .success(FakePerpsTradingService.makeReview())
        let reviewed = XCTestExpectation(description: "review emitted")
        viewModel.onReview = { _ in reviewed.fulfill() }
        try viewModel.continueWithoutAutoClose(XCTUnwrap(refused))
        await fulfillment(of: [reviewed], timeout: 5)

        XCTAssertNil(service.previewedIntents.last?.autoClose?.takeProfit)
        XCTAssertEqual(service.previewedIntents.last?.autoClose?.stopLoss?.triggerPrice, 65000)
    }

    func test_reviewRefusingBothAutoCloseLegs_raisesTheAutoCloseAlert() async {
        let service = FakePerpsTradingService()
        service.previewHandler = { intent in
            if intent.autoClose?.takeProfit != nil { return .failure(.invalidAutoClose(.takeProfit)) }
            if intent.autoClose?.stopLoss != nil { return .failure(.invalidAutoClose(.stopLoss)) }
            return .success(FakePerpsTradingService.makeReview())
        }
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")
        viewModel.applyAutoClose(PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 65000)
        ))

        let alerted = XCTestExpectation(description: "auto close alert")
        var refused: PerpsAutoCloseValidation.InvalidLegs?
        viewModel.onInvalidAutoClose = { refused = $0; alerted.fulfill() }
        viewModel.review()
        await fulfillment(of: [alerted], timeout: 5)

        XCTAssertEqual(refused?.confirmStaleKind, .autoClose)
    }

    func test_reviewRefusedForSlippage_offersOrderNotPlaced() async {
        let service = FakePerpsTradingService()
        service.previewResult = .failure(.slippageExceeded)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")

        let offered = XCTestExpectation(description: "order not placed")
        viewModel.onOrderNotPlaced = { offered.fulfill() }
        viewModel.review()
        await fulfillment(of: [offered], timeout: 5)

        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.Confirm.orderNotPlacedTitle)
    }

    // MARK: - Order type

    func test_orderType_defaultsToMarket_andLimitWithoutPriceBlocksReview() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")
        XCTAssertEqual(viewModel.orderType, .market)
        XCTAssertTrue(viewModel.isReviewEnabled)
        // Switching to limit without a price blocks Review until a price is set.
        viewModel.applyOrderType(.limit)
        XCTAssertEqual(viewModel.orderType, .limit)
        XCTAssertFalse(viewModel.isReviewEnabled)
    }

    func test_openOrderType_passesCurrentSelection() {
        let viewModel = makeViewModel()
        var received: PerpsOrderType?
        viewModel.onOpenOrderType = { received = $0 }
        viewModel.openOrderType()
        XCTAssertEqual(received, .market)
    }

    // MARK: - Limit order

    func test_limitReview_emitsLimitIntent_withEntryAtLimitPrice() async {
        let service = FakePerpsTradingService()
        service.previewResult = .success(FakePerpsTradingService.makeReview(entryPrice: 65000))
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyLeverage(27)
        viewModel.setAmount("20")
        viewModel.applyLimitPrice(65000)

        let reviewed = XCTestExpectation(description: "review emitted")
        var received: PerpsConfirmContext?
        viewModel.onReview = { received = $0; reviewed.fulfill() }
        viewModel.review()

        await fulfillment(of: [reviewed], timeout: 5)
        XCTAssertEqual(received?.intent.limitPrice, 65000)
        XCTAssertEqual(received?.review.entryPrice, 65000)
        XCTAssertEqual(service.previewedIntents.first?.limitPrice, 65000)
    }

    func test_switchingBackToMarket_clearsLimitPrice() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")
        viewModel.applyLimitPrice(65000)
        XCTAssertEqual(viewModel.orderType, .limit)
        viewModel.applyOrderType(.market)
        XCTAssertNil(viewModel.limitPrice)
        XCTAssertEqual(viewModel.headerPriceText, PerpsFormatting.live.usd(66141.70))

        let reviewed = XCTestExpectation(description: "review emitted")
        var received: PerpsConfirmContext?
        viewModel.onReview = { received = $0; reviewed.fulfill() }
        viewModel.review()
        await fulfillment(of: [reviewed], timeout: 5)
        XCTAssertNil(received?.intent.limitPrice)
    }

    func test_limitPriceChange_resetsInvalidAutoClose() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyAutoClose(PerpsAutoClose(
            takeProfit: nil,
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 65000)
        ))
        XCTAssertNotNil(viewModel.autoCloseSummary)

        viewModel.applyLimitPrice(64000)

        XCTAssertNil(viewModel.autoCloseSummary)
        XCTAssertEqual(viewModel.state.autoCloseWarningText, "The Stop Loss value must be below the current price.")
    }

    func test_limitPriceChange_keepsTheAutoCloseLegThatIsStillValid() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyAutoClose(PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 65000)
        ))
        XCTAssertNotNil(viewModel.autoCloseSummary)

        viewModel.applyLimitPrice(64000)

        XCTAssertEqual(viewModel.state.autoClose?.takeProfit?.triggerPrice, 70000)
        XCTAssertNil(viewModel.state.autoClose?.stopLoss)
        XCTAssertEqual(viewModel.state.autoCloseWarningText, "The Stop Loss value must be below the current price.")
    }

    func test_leverageChange_resetsAutoCloseBeyondTheReviewedLiquidation() async {
        let service = FakePerpsTradingService()
        service.reviewer.openReview = Self.openReview(liquidationPrice: 64000)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyAutoClose(PerpsAutoClose(
            takeProfit: nil,
            stopLoss: PerpsAutoCloseTrigger(triggerPrice: 65000)
        ))
        XCTAssertNotNil(viewModel.autoCloseSummary)

        service.reviewer.openReview = Self.openReview(liquidationPrice: 65500)
        viewModel.applyLeverage(40)
        await waitUntil(viewModel) { viewModel.autoCloseSummary == nil }

        XCTAssertEqual(
            viewModel.state.autoCloseWarningText,
            "The Stop Loss value must be above the liquidation price (\(PerpsFormatting.live.usd(65500)))."
        )
    }

    func test_leverageSheet_reloadsAStaleRead_andShowsItsLiquidation() async throws {
        let service = FakePerpsTradingService()
        service.reviewer.openReview = Self.openReview(liquidationPrice: 64000)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.state.liquidationPrice == 64000 }
        var sheetContext: PerpsLeverageSheetContext?
        viewModel.onOpenLeverage = { sheetContext = $0 }
        viewModel.openLeverage()

        service.reviewer.isStale = true
        service.reviewer.openReview = nil
        let sheet = try PerpsLeverageSheetViewModel(
            context: XCTUnwrap(sheetContext),
            format: PerpsFormatting.live,
            reviewLiquidation: { viewModel.reviewedLiquidation(forLeverage: $0) },
            reviewerLoaded: viewModel.reviewerLoaded
        )
        XCTAssertNil(sheet.liquidationText)

        service.reviewer.isStale = false
        service.reviewer.openReview = Self.openReview(liquidationPrice: 63000)
        await waitUntil(viewModel) { sheet.liquidationText != nil }

        XCTAssertEqual(sheet.liquidationText, PerpsFormatting.live.usd(63000))
        XCTAssertEqual(service.reviewerLoads, 2)
    }

    func test_leverageSheet_readThatLandsStale_doesNotReloadAgain() async throws {
        let service = FakePerpsTradingService()
        service.reviewer.openReview = Self.openReview(liquidationPrice: 64000)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.state.liquidationPrice == 64000 }
        var sheetContext: PerpsLeverageSheetContext?
        viewModel.onOpenLeverage = { sheetContext = $0 }
        viewModel.openLeverage()

        service.reviewer.isStale = true
        let sheet = try PerpsLeverageSheetViewModel(
            context: XCTUnwrap(sheetContext),
            format: PerpsFormatting.live,
            reviewLiquidation: { viewModel.reviewedLiquidation(forLeverage: $0) },
            reviewerLoaded: viewModel.reviewerLoaded
        )
        service.reviewer.openReview = Self.openReview(liquidationPrice: 63000)
        var spins = 0
        while sheet.liquidationText != PerpsFormatting.live.usd(63000), spins < 100_000 {
            spins += 1
            await Task.yield()
        }
        for _ in 0 ..< 100 {
            await Task.yield()
        }

        XCTAssertEqual(sheet.liquidationText, PerpsFormatting.live.usd(63000))
        XCTAssertEqual(service.reviewerLoads, 2)
    }

    func test_livePriceTick_movesTheHeaderAndTheAutoCloseReference_andLeavesTheDraftAlone() async {
        let client = FakeMarkPricesClient()
        let viewModel = makeViewModel(marketsStore: .makeForTests(tickers: [1: "BTC/USD"], client: client))
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready }
        viewModel.applyAutoClose(PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 67000), stopLoss: nil))
        XCTAssertNotNil(viewModel.autoCloseSummary)

        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67500")])
        await waitUntil(viewModel) { viewModel.headerPriceText == PerpsFormatting.live.usd(67500) }

        XCTAssertEqual(viewModel.headerPriceText, PerpsFormatting.live.usd(67500))
        XCTAssertEqual(viewModel.state.autoClose?.takeProfit?.triggerPrice, 67000)
        XCTAssertNil(viewModel.state.autoCloseWarningText)
        var sheet: PerpsAutoCloseSheetContext?
        viewModel.onOpenAutoClose = { sheet = $0 }
        viewModel.openAutoClose()
        XCTAssertEqual(sheet?.referencePrice, 67500)
        XCTAssertEqual(sheet?.livePriceMarketId, 1)
    }

    func test_legTypedAsROI_followsThePriceAndLeverage_andReopensAsTyped() async throws {
        let client = FakeMarkPricesClient()
        let service = FakePerpsTradingService()
        let viewModel = makeViewModel(service: service, marketsStore: .makeForTests(tickers: [1: "BTC/USD"], client: client))
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "66000")])
        await waitUntil(viewModel) { viewModel.effectivePrice == 66000 }
        viewModel.applyLeverage(10)
        // +10% at 10x is a 1% move: 66000 → 66660.
        viewModel.applyAutoClose(
            PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 66660), stopLoss: nil),
            roiInput: PerpsAutoCloseROIInput(takeProfit: PerpsAutoCloseROI(sign: .plus, text: "10"))
        )
        XCTAssertEqual(viewModel.autoCloseSummary, "\(PerpsFormatting.live.signedPercent(10)) TP")

        await client.emit([("BTC/USD", "67000")])
        await waitUntil(viewModel) { viewModel.effectivePrice == 67000 }
        XCTAssertEqual(try XCTUnwrap(viewModel.autoClose?.takeProfit?.triggerPrice), 67670, accuracy: 1e-6)
        XCTAssertNil(viewModel.state.autoCloseWarningText)

        var sheet: PerpsAutoCloseSheetContext?
        viewModel.onOpenAutoClose = { sheet = $0 }
        viewModel.openAutoClose()
        let reopened = try PerpsAutoCloseSheetViewModel(context: XCTUnwrap(sheet), format: PerpsFormatting.live)
        XCTAssertEqual(reopened.takeProfitPercentText, "10")
        XCTAssertEqual(reopened.takeProfitPriceText, "67670")

        viewModel.applyLeverage(20)
        XCTAssertEqual(try XCTUnwrap(viewModel.autoClose?.takeProfit?.triggerPrice), 67335, accuracy: 1e-6)

        viewModel.setAmount("20")
        let reviewed = XCTestExpectation(description: "review emitted")
        var confirmed: PerpsConfirmContext?
        viewModel.onReview = { confirmed = $0; reviewed.fulfill() }
        viewModel.review()
        await fulfillment(of: [reviewed], timeout: 5)
        XCTAssertEqual(try XCTUnwrap(confirmed?.intent.autoClose?.takeProfit?.triggerPrice), 67335, accuracy: 1e-6)
    }

    func test_leverageChange_preservesUnplaceableROI_andBlocksReviewUntilCorrected() async throws {
        let viewModel = makeViewModel(side: .short)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")
        viewModel.applyLeverage(10)
        let input = PerpsAutoCloseROIInput(takeProfit: PerpsAutoCloseROI(sign: .plus, text: "100"))
        viewModel.applyAutoClose(
            PerpsAutoClose(takeProfit: PerpsAutoCloseTrigger(triggerPrice: 59527.53), stopLoss: nil),
            roiInput: input
        )
        XCTAssertTrue(viewModel.isReviewEnabled)

        viewModel.applyLeverage(1)
        XCTAssertNotNil(viewModel.autoClose?.takeProfit)
        XCTAssertEqual(viewModel.autoCloseROIInput, input)
        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.Error.autoCloseInvalid)
        XCTAssertFalse(viewModel.isReviewEnabled)

        var context: PerpsAutoCloseSheetContext?
        viewModel.onOpenAutoClose = { context = $0 }
        viewModel.openAutoClose()
        let sheet = try PerpsAutoCloseSheetViewModel(context: XCTUnwrap(context), format: PerpsFormatting.live)
        XCTAssertEqual(sheet.takeProfitPercentText, "100")
        XCTAssertFalse(sheet.isApplyEnabled)

        viewModel.applyLeverage(10)
        XCTAssertEqual(try XCTUnwrap(viewModel.autoClose?.takeProfit?.triggerPrice), 59527.53, accuracy: 1e-6)
        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertNil(viewModel.warningText)

        viewModel.applyLeverage(1)
        viewModel.applyAutoClose(nil)
        XCTAssertEqual(viewModel.autoCloseROIInput, .none)
        XCTAssertNil(viewModel.warningText)
        XCTAssertTrue(viewModel.isReviewEnabled)
    }

    func test_legTypedAsPrice_staysPut_whenTheRestOfTheDraftWasTypedAsROI() async throws {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready }
        viewModel.applyAutoClose(
            PerpsAutoClose(
                takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
                stopLoss: PerpsAutoCloseTrigger(triggerPrice: 65000)
            ),
            roiInput: PerpsAutoCloseROIInput(stopLoss: PerpsAutoCloseROI(sign: .minus, text: "27"))
        )
        viewModel.applyLeverage(54)

        XCTAssertEqual(viewModel.autoClose?.takeProfit?.triggerPrice, 70000)
        // −27% at 54x is a 0.5% move below 66141.70.
        XCTAssertEqual(try XCTUnwrap(viewModel.autoClose?.stopLoss?.triggerPrice), 65810.99, accuracy: 1e-6)
        XCTAssertEqual(
            viewModel.autoCloseSummary,
            "\(PerpsFormatting.live.usd(70000)) TP · \(PerpsFormatting.live.signedPercent(-27)) SL"
        )
    }

    // MARK: - Size in the asset

    func test_tokenMode_takesTheSizeInTheAsset_andReviewsItsMargin() async {
        let service = FakePerpsTradingService()
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyLeverage(10)
        viewModel.toggleSizeMode()
        viewModel.setAmount("0.0123456")

        XCTAssertEqual(viewModel.amountText, "0.01234")
        XCTAssertEqual(viewModel.amountPrefix, "")
        XCTAssertEqual(viewModel.amountSuffix, "BTC")
        XCTAssertEqual(viewModel.sizeTitle, TKLocales.Perps.OpenPosition.margin)
        XCTAssertEqual(viewModel.marginUsd, 0.01234 * 66141.70 / 10, accuracy: 1e-6)
        XCTAssertEqual(viewModel.sizeText, PerpsFormatting.live.usd(viewModel.marginUsd))

        let reviewed = XCTestExpectation(description: "review emitted")
        viewModel.onReview = { _ in reviewed.fulfill() }
        viewModel.review()
        await fulfillment(of: [reviewed], timeout: 5)
        XCTAssertEqual(service.previewedIntents.first?.marginUsd, "81.618858")
        XCTAssertEqual(service.previewedIntents.first?.leverage, 10)
    }

    func test_toggle_convertsTheAmountBetweenMarginAndAssetSize() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyLeverage(10)
        viewModel.setAmount("100")

        viewModel.toggleSizeMode()
        XCTAssertEqual(viewModel.sizeMode, .token)
        XCTAssertEqual(viewModel.amountText, "0.01511")

        viewModel.toggleSizeMode()
        XCTAssertEqual(viewModel.sizeMode, .usd)
        XCTAssertEqual(viewModel.amountText, "99.94")
        XCTAssertEqual(viewModel.amountPrefix, "$")
        XCTAssertNil(viewModel.amountSuffix)
        XCTAssertEqual(viewModel.sizeTitle, TKLocales.Perps.OpenPosition.size)
    }

    func test_tokenMode_onAWholeUnitMarket_dropsTheFraction() async {
        let service = FakePerpsTradingService()
        service.context = FakePerpsTradingService.makeContext(displayPrice: 2.5, sizeDecimals: 0)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.toggleSizeMode()

        viewModel.setAmount("10.")
        XCTAssertEqual(viewModel.amountText, "10")
        viewModel.setAmount("010.5")
        XCTAssertEqual(viewModel.amountText, "10")
    }

    func test_toggle_withoutAPrice_keepsTheDollarAmount() async {
        let service = FakePerpsTradingService()
        service.context = FakePerpsTradingService.makeContext(displayPrice: 0)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("500")

        viewModel.toggleSizeMode()
        XCTAssertEqual(viewModel.sizeMode, .usd)
        XCTAssertEqual(viewModel.amountText, "500")
    }

    func test_tokenMode_max_fillsTheSizeTheBalanceCovers() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyLeverage(10)
        viewModel.toggleSizeMode()
        viewModel.setMax()

        XCTAssertEqual(viewModel.amountText, "0.10773")
        XCTAssertLessThanOrEqual(viewModel.marginUsd, 712.56)
        XCTAssertTrue(viewModel.isReviewEnabled)
    }

    func test_tokenMode_livePriceTickDuringReview_keepsTheReviewedDraft() async {
        let client = FakeMarkPricesClient()
        let service = FakePerpsTradingService()
        let viewModel = makeViewModel(service: service, marketsStore: .makeForTests(tickers: [1: "BTC/USD"], client: client))
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        await waitForTickers(client, toEqual: ["BTC/USD"])
        viewModel.applyLeverage(10)
        viewModel.toggleSizeMode()
        viewModel.setAmount("0.01")

        let (entered, enteredContinuation) = AsyncStream<Void>.makeStream()
        let (release, releaseContinuation) = AsyncStream<Void>.makeStream()
        service.previewSuspension = {
            enteredContinuation.yield()
            for await _ in release {
                break
            }
        }
        let reviewed = XCTestExpectation(description: "review emitted")
        var received: PerpsConfirmContext?
        viewModel.onReview = { received = $0; reviewed.fulfill() }
        viewModel.review()

        for await _ in entered {
            break
        }
        await client.emit([("BTC/USD", "67500")])
        await waitUntil(viewModel) { viewModel.headerPriceText == PerpsFormatting.live.usd(67500) }
        releaseContinuation.yield()

        await fulfillment(of: [reviewed], timeout: 5)
        XCTAssertEqual(received?.intent.marginUsd, "66.1417")
        XCTAssertNil(viewModel.warningText)
    }

    private static func openReview(liquidationPrice: Double) -> PerpsOpenOrderReview {
        PerpsOpenOrderReview(
            symbol: "BTC",
            marginUsd: 100,
            entryPrice: 66000,
            liquidationPrice: liquidationPrice,
            notionalUsd: 1000,
            baseSize: 0.015,
            estimatedFeeUsd: 0.4,
            liquidationUnavailableReason: nil
        )
    }

    // MARK: - Helpers

    private func waitUntil(
        _ viewModel: PerpsOpenPositionViewModel,
        timeout: TimeInterval = 5,
        _ condition: @escaping () -> Bool
    ) async {
        let fulfilled = XCTestExpectation(description: "view model condition")
        fulfilled.assertForOverFulfill = false
        let cancellable = viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in if condition() { fulfilled.fulfill() } }
        if condition() { fulfilled.fulfill() }
        await fulfillment(of: [fulfilled], timeout: timeout)
        cancellable.cancel()
    }
}

/// Match the `.ready` case without comparing the parsed balance — `Decimal → Double` isn't
/// bit-identical to a literal, so an `== .ready(balance: 712.56)` check is flaky.
@MainActor
private func accountIsReady(_ viewModel: PerpsOpenPositionViewModel) -> Bool {
    if case .ready = viewModel.account { return true }
    return false
}

private extension Wallet {
    static func openPositionTest() -> Wallet {
        let raw = Data("perps-open-position-test".utf8)
        let padded = raw + Data(repeating: 0, count: max(0, 32 - raw.count))
        let publicKey = TonSwift.PublicKey(data: Data(padded.prefix(32)))
        return Wallet(
            id: "perps-open-position-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Perps Open Position Test", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class AccountReadingSpy: PerpsAccountReading, @unchecked Sendable {
    var statusResult: PerpsAccountStatus = .unknown
    var portfolioResult: PerpsAccountSnapshot?
    private(set) var portfolioCallCount = 0

    func status(wallet: Wallet) async -> PerpsAccountStatus {
        statusResult
    }

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot? {
        portfolioCallCount += 1
        return portfolioResult
    }

    func tradingSnapshot(wallet: Wallet, marketId: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
    }

    func watchPositions(
        wallet: Wallet,
        pollInterval _: TimeInterval,
        focus _: @escaping @Sendable () -> PerpsWatchFocus,
        onUpdate: @escaping @Sendable (PerpsAccountTick) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        PerpsPositionsWatch {}
    }
}

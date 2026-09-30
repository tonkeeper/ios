@testable import App
import ChainKit
import Combine
@testable import KeeperCore
import TKLocalize
import TonSwift
import XCTest

final class PerpsAssetPageViewModelTests: XCTestCase {
    /// View models created via the helpers, torn down after each test so the markets
    /// store's live watch (a perpetual flush task) is always stopped and can't
    /// accumulate across the suite.
    private var trackedViewModels: [PerpsAssetPageViewModel] = []

    @MainActor
    override func tearDown() async throws {
        trackedViewModels.forEach { $0.onDisappear() }
        trackedViewModels.removeAll()
        try await super.tearDown()
    }

    // MARK: Snapshot mapper

    func test_snapshotMapper_nameFallsBackToSymbol_andAboutNil() {
        let snapshot = PerpsAssetMarketSnapshot(details: .test(metadata: makeMarket(symbol: "BTC")))
        XCTAssertEqual(snapshot.displayName, "BTC")
        XCTAssertNil(snapshot.about)
        XCTAssertNil(snapshot.iconURL)
        XCTAssertEqual(snapshot.priceDecimals, 2)
        XCTAssertTrue(snapshot.isTradingEnabled)
    }

    func test_snapshotMapper_funding_usesMetadata() {
        let market = makeMarket(fundingRatePercent: 0.00032385)
        let snapshot = PerpsAssetMarketSnapshot(details: .test(metadata: market))
        XCTAssertEqual(snapshot.fundingRatePercent ?? .nan, 0.00032385, accuracy: 1e-9)
    }

    func test_snapshotMapper_funding_nilWithoutMetadata() {
        let snapshot = PerpsAssetMarketSnapshot(details: .test(metadata: makeMarket(fundingRatePercent: nil)))
        XCTAssertNil(snapshot.fundingRatePercent)
    }

    func test_snapshotMapper_inactiveStatus_disablesTrading() {
        let snapshot = PerpsAssetMarketSnapshot(details: .test(metadata: makeMarket(status: "paused")))
        XCTAssertFalse(snapshot.isTradingEnabled)
    }

    func test_overlayingLivePrice_rederivesChangeAgainstSnapshotBaseline() {
        let snapshot = PerpsAssetMarketSnapshot(
            details: .test(metadata: makeMarket(lastTradePrice: 100, dailyPriceChange: 4.37))
        )
        let overlaid = snapshot.overlayingLivePrice(110)
        XCTAssertEqual(overlaid.price, 110)
        // baseline = 100 / 1.0437; live percent = (110 / baseline - 1) × 100.
        let baseline = 100.0 / 1.0437
        XCTAssertEqual(overlaid.priceChangePercent, (110 / baseline - 1) * 100, accuracy: 1e-9)
        XCTAssertEqual(
            overlaid.priceChangeAmount,
            PerpsMarketMath.changeAmount(price: 110, changePercent: overlaid.priceChangePercent),
            accuracy: 1e-9
        )
        XCTAssertEqual(overlaid.volume24h, snapshot.volume24h)
    }

    func test_overlayingLivePrice_keepsSnapshotPercent_whenBaselineDegenerate() {
        let snapshot = PerpsAssetMarketSnapshot(
            details: .test(metadata: makeMarket(lastTradePrice: 100, dailyPriceChange: -99.5))
        )
        let overlaid = snapshot.overlayingLivePrice(50)
        XCTAssertEqual(overlaid.price, 50)
        XCTAssertEqual(overlaid.priceChangePercent, -99.5, accuracy: 1e-9)
    }

    func test_changeAmount_guardsNearMinus100Percent() {
        // factor = 1 + (-99.5)/100 = 0.005 < 0.01 -> degenerate, returns 0 (not a huge value).
        XCTAssertEqual(PerpsMarketMath.changeAmount(price: 100, changePercent: -99.5), 0, accuracy: 1e-9)
        // Normal case still derives a sane amount.
        XCTAssertEqual(
            PerpsMarketMath.changeAmount(price: 100, changePercent: 4.37),
            100 - 100 / 1.0437,
            accuracy: 1e-6
        )
    }

    // MARK: Position and activity derivations

    func test_positionSummary_carriesVenueLeverageAndRoiRatherThanDerivingThem() {
        let position = makeSummary(notionalUsd: 540, marginUsd: 20, leverage: 27, roiPercent: 2.5)
        XCTAssertEqual(position.leverage ?? .nan, 27, accuracy: 1e-9)
        XCTAssertEqual(position.roiPercent ?? .nan, 2.5, accuracy: 1e-9)

        let drifted = makeSummary(notionalUsd: 594, marginUsd: 20, leverage: 27, roiPercent: 2.5)
        XCTAssertEqual(drifted.leverage ?? .nan, 27, accuracy: 1e-9)
        XCTAssertEqual(drifted.roiPercent ?? .nan, 2.5, accuracy: 1e-9)

        let withheld = makeSummary(notionalUsd: 540, marginUsd: 0, leverage: nil, roiPercent: nil)
        XCTAssertNil(withheld.leverage)
        XCTAssertNil(withheld.roiPercent)
    }

    func test_triggerProjection_signedByPositionDirection() {
        let long = makeSummary(side: .long, entryPrice: 100, notionalUsd: 100, marginUsd: 20)
        let longTP = long.triggerProjection(triggerPrice: 110, baseAmount: 1)
        XCTAssertEqual(longTP.pnlUsd, 10, accuracy: 1e-9)
        XCTAssertEqual(longTP.roePercent ?? .nan, 50, accuracy: 1e-9)

        let short = makeSummary(side: .short, entryPrice: 100, notionalUsd: 100, marginUsd: 20)
        XCTAssertEqual(short.triggerProjection(triggerPrice: 110, baseAmount: 1).pnlUsd, -10, accuracy: 1e-9)
    }

    func test_triggerOrder_cancelsByClientIndexWhenItHasOne() {
        XCTAssertEqual(makeTrigger(orderIndex: 7, clientOrderIndex: 42).cancelKey, 42)
        XCTAssertEqual(makeTrigger(orderIndex: 7, clientOrderIndex: 0).cancelKey, 7)
    }

    func test_activityOutcome_inferredFromKindAndRealizedPnl() {
        XCTAssertEqual(makeActivity(kind: .trade).outcome, .opened)
        XCTAssertEqual(makeActivity(kind: .trade, realizedPnl: 5).outcome, .closed)
        XCTAssertEqual(makeActivity(kind: .liquidation).outcome, .liquidated)
        XCTAssertEqual(makeActivity(kind: .funding).outcome, .funding)
        XCTAssertEqual(makeActivity(kind: .deposit).outcome, .other)
    }

    // MARK: View model — load via shared store

    @MainActor
    func test_onAppear_loadsMarketDetails_becomesReady() async {
        let spy = MarketsReadingSpy()
        let (viewModel, _) = makeViewModel(service: spy, marketId: 1)

        viewModel.onAppear()

        await waitUntil(viewModel) { viewModel.state.ready != nil }
        XCTAssertEqual(viewModel.state.ready?.symbol, "BTC")
        viewModel.onDisappear()
    }

    @MainActor
    func test_marketDetailsNotFound_becomesNotFound() async {
        let spy = MarketsReadingSpy()
        let (viewModel, _) = makeViewModel(
            service: spy,
            marketId: 1,
            tradingError: .notFound
        )

        viewModel.onAppear()

        await waitUntil(viewModel) { viewModel.state == .notFound }
        viewModel.onDisappear()
    }

    @MainActor
    func test_livePriceTick_updatesPriceWithoutReplacingVolume() async {
        let spy = MarketsReadingSpy()
        spy.marketsResult = [.test(id: 1, symbol: "BTC", price: 100)]
        let snapshot = makeSnapshot()
        let client = FakeMarkPricesClient()
        let (viewModel, _) = makeViewModel(service: spy, marketId: 1, tradingSnapshot: snapshot, pricesClient: client)

        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.state.ready != nil }
        await waitForTickers(client, toEqual: ["BTC/USD"])

        await client.emit([("BTC/USD", "200")])

        await waitUntil(viewModel, timeout: 3) { viewModel.state.ready?.priceText == PerpsFormatting.usd(200) }
        XCTAssertEqual(viewModel.state.ready?.volumeText, PerpsFormatting.usd(snapshot.volume24h))
        viewModel.onDisappear()
    }

    @MainActor
    func test_missingLivePrice_keepsScreenReady() async {
        let spy = MarketsReadingSpy()
        let snapshot = PerpsAssetMarketSnapshot(
            marketId: 1, symbol: "ETH", displayName: "ETH",
            status: "active", maxLeverage: 20, priceDecimals: 2, sizeDecimals: 4,
            price: 0, priceChangePercent: 0, priceChangeAmount: 0,
            volume24h: 1000, openInterest: 500, fundingRatePercent: nil, about: nil,
            openEnabled: true
        )
        let (viewModel, _) = makeViewModel(service: spy, marketId: 1, tradingSnapshot: snapshot)

        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.state.ready != nil }
        XCTAssertEqual(viewModel.state.ready?.priceText, "")
        XCTAssertEqual(viewModel.state.ready?.volumeText, PerpsFormatting.usd(1000))
        XCTAssertEqual(viewModel.state.ready?.actions, .longShort(enabled: true))
        viewModel.onDisappear()
    }

    @MainActor
    func test_openPositionFlowSubmitting_togglesLongShort() async {
        let flow = PerpsOpenPositionFlow()
        let (viewModel, _) = makeViewModel(service: MarketsReadingSpy(), marketId: 1, openPositionFlow: flow)

        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.state.ready?.actions == .longShort(enabled: true) }

        _ = flow.begin(marketId: 1)
        _ = flow.beginSubmitting(PerpsOpeningDescriptor(
            marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 27, isLimit: false
        ))
        await waitUntil(viewModel) { viewModel.state.ready?.actions == .longShort(enabled: false) }

        flow.finishSubmitting()
        await waitUntil(viewModel) { viewModel.state.ready?.actions == .longShort(enabled: true) }
        viewModel.onDisappear()
    }

    @MainActor
    func test_foreignTradingSnapshot_isNotShownAsReady() async {
        let wallet = Wallet.assetPageTest()
        let spy = MarketDetailsLoadingSpy()
        spy.snapshot = makeSnapshot()
        let detailsStore = PerpsMarketDetailsStore(service: spy)
        detailsStore.load(marketId: 1)
        await waitUntilStore(detailsStore) {
            if case .loaded = $0 { return true }
            return false
        }

        let marketsStore = PerpsMarketsStore.makeForTests(service: MarketsReadingSpy())
        let accountStore = PerpsAccountStore(service: AccountReadingSpy(), wallet: wallet)
        let viewModel = PerpsAssetPageViewModel(
            marketId: 2,
            store: marketsStore,
            marketDetailsStore: detailsStore,
            accountStore: accountStore,
            openPositionFlow: PerpsOpenPositionFlow()
        )
        trackedViewModels.append(viewModel)

        XCTAssertNil(viewModel.state.ready)
        XCTAssertEqual(viewModel.state, .loading)
        viewModel.onDisappear()
    }

    // MARK: Account store — live positions stream

    @MainActor
    func test_subscribingOpensLivePositionsWatch_whenActive() async {
        let wallet = Wallet.assetPageTest()
        let spy = LivePositionsAccountSpy()
        let store = PerpsAccountStore(service: spy, wallet: wallet)
        store.subscribePositions()
        store.resolveIfNeeded()

        // Regression: the socket must open once the account resolves to active — it
        // must not depend on the `.active` state's asynchronously-committed
        // resolvedWalletId (which isn't set yet when applyActive starts the watch).
        await fulfillment(of: [spy.watchOpened], timeout: 5)
        XCTAssertNotNil(spy.capturedOnUpdate)
        store.unsubscribePositions()
    }

    // MARK: View model — state mapping (pure `reduce`, no live stores)

    func test_flatLifecycle_showsLongShort() {
        let ready = reduceReady(lifecycle: .flat, extras: extras(flags: flags()))
        XCTAssertNil(ready?.position)
        XCTAssertEqual(ready?.actions, .longShort(enabled: true))
    }

    func test_inactiveMarket_disablesLongShort() {
        XCTAssertEqual(
            reduceReady(lifecycle: .flat, tradingEnabled: false, isAccountActive: false)?.actions,
            .longShort(enabled: false)
        )
    }

    func test_openPositionSubmitting_disablesLongShort() {
        XCTAssertEqual(
            reduceReady(lifecycle: .flat, extras: extras(flags: flags()), isOpenPositionSubmitting: true)?.actions,
            .longShort(enabled: false)
        )
    }

    func test_openLongPosition_rendersBlockAndEditCashOut() {
        // notional 540 / margin 20 = 27x; +PnL.
        let ready = reduceReady(
            lifecycle: .open(summary(side: .long, notionalUsd: 540, marginUsd: 20, unrealizedPnlUsd: 0.5)),
            extras: extras(flags: flags())
        )
        let block = ready?.position
        XCTAssertEqual(block?.isLong, true)
        XCTAssertEqual(block?.sideText, TKLocales.Perps.Asset.long.uppercased())
        XCTAssertEqual(block?.leverageText, PerpsFormatting.leverage(27).uppercased())
        XCTAssertTrue(block?.isPnlPositive ?? false)
        XCTAssertEqual(ready?.actions, .editCashOut(editEnabled: true, cashOutEnabled: true))
    }

    // MARK: Backend action flags

    func test_openPosition_withoutFlags_refusesEveryAction() {
        let ready = reduceReady(lifecycle: .open(summary()), extras: extras(flags: nil))
        XCTAssertEqual(ready?.actions, .editCashOut(editEnabled: false, cashOutEnabled: false))
        XCTAssertEqual(ready?.canAdjustMargin, false)
        XCTAssertEqual(ready?.canEditAutoClose, false)
        XCTAssertEqual(ready?.canCancelOrders, false)
    }

    func test_flatMarket_withoutAnActiveAccount_stillFollowsTheCatalog() {
        XCTAssertEqual(
            reduceReady(lifecycle: .flat, extras: nil, isAccountActive: false)?.actions,
            .longShort(enabled: true)
        )
        XCTAssertEqual(
            reduceReady(lifecycle: .flat, extras: nil, isAccountActive: true)?.actions,
            .longShort(enabled: false)
        )
    }

    func test_unreadableAutoCloseLegs_areNotOfferedAsAbsent() {
        let ready = reduceReady(
            lifecycle: .open(summary()),
            extras: extras(flags: flags(), autoCloseKnown: false)
        )
        XCTAssertEqual(ready?.autoClose, PerpsAssetPageViewModel.AutoCloseAffordance.none)

        let readable = reduceReady(lifecycle: .open(summary()), extras: extras(flags: flags()))
        XCTAssertEqual(readable?.autoClose, .setAutoClose)
    }

    func test_closeDisabledByBackend_disablesCashOutButKeepsEdit() {
        let ready = reduceReady(
            lifecycle: .open(summary()),
            extras: extras(flags: flags(closeEnabled: false))
        )
        XCTAssertEqual(ready?.actions, .editCashOut(editEnabled: true, cashOutEnabled: false))
    }

    func test_openDisabledByBackend_disablesLongShort_evenOnAnActiveMarket() {
        let ready = reduceReady(
            lifecycle: .flat,
            extras: extras(flags: flags(openEnabled: false)),
            tradingEnabled: true
        )
        XCTAssertEqual(ready?.actions, .longShort(enabled: false))
    }

    func test_marginAndAutoCloseFlags_gateTheManageRows() {
        let ready = reduceReady(
            lifecycle: .open(summary()),
            extras: extras(flags: flags(addMarginEnabled: false, removeMarginEnabled: false, autoCloseEnabled: false))
        )
        XCTAssertEqual(ready?.canAdjustMargin, false)
        XCTAssertEqual(ready?.canEditAutoClose, false)
    }

    func test_oneMarginDirectionDisabled_stillOffersTheRow() {
        let ready = reduceReady(
            lifecycle: .open(summary()),
            extras: extras(flags: flags(removeMarginEnabled: false))
        )
        XCTAssertEqual(ready?.canAdjustMargin, true)
    }

    func test_aPartialFlagsBlock_refusesTheUnsaidCapabilities() {
        let ready = reduceReady(
            lifecycle: .open(summary()),
            extras: extras(flags: flags(
                openEnabled: nil,
                closeEnabled: nil,
                cancelEnabled: true,
                addMarginEnabled: nil,
                removeMarginEnabled: nil,
                autoCloseEnabled: nil
            ))
        )
        XCTAssertEqual(ready?.actions, .editCashOut(editEnabled: false, cashOutEnabled: false))
        XCTAssertEqual(ready?.canAdjustMargin, false)
        XCTAssertEqual(ready?.canEditAutoClose, false)
        XCTAssertEqual(ready?.canCancelOrders, true)
    }

    func test_bothTradeDirectionsDisabled_disablesEditToo() {
        let ready = reduceReady(
            lifecycle: .open(summary()),
            extras: extras(flags: flags(openEnabled: false, closeEnabled: false))
        )
        XCTAssertEqual(ready?.actions, .editCashOut(editEnabled: false, cashOutEnabled: false))
    }

    func test_editDirections_followTheSameFlagsAsTheActionBar() {
        let snapshot = makeSnapshot()
        XCTAssertEqual(
            PerpsAssetPageViewModel.editDirections(snapshot: snapshot, flags: flags(), isAccountActive: true),
            [.add, .reduce]
        )
        XCTAssertEqual(
            PerpsAssetPageViewModel.editDirections(
                snapshot: snapshot,
                flags: flags(openEnabled: false),
                isAccountActive: true
            ),
            [.reduce]
        )
        XCTAssertEqual(
            PerpsAssetPageViewModel.editDirections(
                snapshot: snapshot,
                flags: flags(closeEnabled: false),
                isAccountActive: true
            ),
            [.add]
        )
        XCTAssertEqual(
            PerpsAssetPageViewModel.editDirections(
                snapshot: snapshot,
                flags: flags(openEnabled: false, closeEnabled: false),
                isAccountActive: true
            ),
            []
        )
    }

    func test_editDirections_withoutFlags_offerNothing() {
        XCTAssertEqual(
            PerpsAssetPageViewModel.editDirections(snapshot: makeSnapshot(), flags: nil, isAccountActive: true),
            []
        )
    }

    func test_cancelDisabledByBackend_marksOrdersUncancellable() {
        let ready = reduceReady(
            lifecycle: .open(summary()),
            extras: extras(flags: flags(cancelEnabled: false))
        )
        XCTAssertEqual(ready?.canCancelOrders, false)
    }

    func test_shortPosition_mapsSideAndNegativePnl() {
        let ready = reduceReady(lifecycle: .open(summary(side: .short, unrealizedPnlUsd: -3)))
        XCTAssertEqual(ready?.position?.isLong, false)
        XCTAssertEqual(ready?.position?.isPnlPositive, false)
    }

    func test_openingLifecycle_hidesActions_andProgressToast() {
        let descriptor = PerpsOpeningDescriptor(marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 27, isLimit: false)
        let ready = reduceReady(lifecycle: .opening(descriptor))
        XCTAssertEqual(ready?.actions, .hidden)
        XCTAssertNil(ready?.position)
        guard case .progress = PerpsAssetPageViewModel.lifecycleToast(.opening(descriptor)) else {
            return XCTFail("expected progress toast while opening")
        }
    }

    func test_closingLifecycle_keepsBlock_disablesActions_andShowsProgressPill() {
        let closing = summary(notionalUsd: 540, marginUsd: 20)
        let ready = reduceReady(lifecycle: .closing(closing))
        XCTAssertNotNil(ready?.position)
        XCTAssertEqual(ready?.actions, .editCashOut(editEnabled: false, cashOutEnabled: false))
        guard case let .progress(text) = PerpsAssetPageViewModel.lifecycleToast(.closing(closing)) else {
            return XCTFail("expected progress toast while closing")
        }
        // Design pill copy: "Closing BTC long · 27x".
        XCTAssertEqual(
            text,
            "\(TKLocales.Perps.Toast.closing) BTC \(TKLocales.Perps.Asset.long.lowercased()) · \(PerpsFormatting.leverage(27))"
        )
    }

    func test_adjustingLifecycle_keepsBlock_disablesActions_andShowsDirectionPill() {
        let adjusting = summary(notionalUsd: 540, marginUsd: 20)
        let ready = reduceReady(lifecycle: .adjusting(adjusting, .add))
        XCTAssertNotNil(ready?.position)
        XCTAssertEqual(ready?.actions, .editCashOut(editEnabled: false, cashOutEnabled: false))
        guard case let .progress(text) = PerpsAssetPageViewModel.lifecycleToast(.adjusting(adjusting, .add)) else {
            return XCTFail("expected progress toast while adjusting")
        }
        // Design pill copy: "Increasing BTC long · 27x".
        XCTAssertEqual(
            text,
            "\(TKLocales.Perps.Toast.increasing) BTC \(TKLocales.Perps.Asset.long.lowercased()) · \(PerpsFormatting.leverage(27))"
        )
        guard case let .progress(reducing) = PerpsAssetPageViewModel.lifecycleToast(.adjusting(adjusting, .reduce)) else {
            return XCTFail("expected progress toast while reducing")
        }
        XCTAssertTrue(reducing.hasPrefix(TKLocales.Perps.Toast.reducing))
    }

    func test_reduce_keepsLastReadyDuringTransientFailure() {
        let previous = reduceReady(lifecycle: .flat).map(PerpsAssetPageViewModel.State.ready) ?? .loading
        // A failed/notFound market input must not blank a page that already had content.
        XCTAssertNotNil(PerpsAssetPageViewModel.reduce(market: .failed, lifecycle: .flat, extras: nil, isAccountActive: true, isOpenPositionSubmitting: false, previous: previous).ready)
        XCTAssertNotNil(PerpsAssetPageViewModel.reduce(market: .notFound, lifecycle: .flat, extras: nil, isAccountActive: true, isOpenPositionSubmitting: false, previous: previous).ready)
        // From no content, notFound stays a distinct empty state.
        XCTAssertEqual(PerpsAssetPageViewModel.reduce(market: .notFound, lifecycle: .flat, extras: nil, isAccountActive: true, isOpenPositionSubmitting: false, previous: .loading), .notFound)
    }

    // MARK: View model — Orders + Auto Close + history mapping

    func test_ordersBlock_projectedPnl_andSetMissingLeg() {
        let extras = PerpsMarketExtras(
            triggerOrders: [PerpsTriggerOrderSummary(orderIndex: 1, kind: .takeProfit, side: .short, triggerPrice: 68141.7, baseAmount: 1)],
            recentActivity: []
        )
        let ready = reduceReady(lifecycle: .open(summary(side: .long, baseSize: 1, entryPrice: 66541.7)), extras: extras)
        let order = ready?.orders.first
        XCTAssertEqual(order?.kindText, TKLocales.Perps.OpenPosition.tp)
        XCTAssertEqual(order?.actionText, "\(TKLocales.Perps.Asset.sell) 100%")
        XCTAssertEqual(order?.isPositive, true) // TP above entry on a long
        XCTAssertNotNil(order?.valueText)
        XCTAssertEqual(ready?.autoClose, .setStopLoss) // only TP set
    }

    func test_positionTiedOrder_projectsAgainstFullLivePosition() {
        let extras = PerpsMarketExtras(
            triggerOrders: [PerpsTriggerOrderSummary(
                orderIndex: 1,
                kind: .takeProfit,
                side: .short,
                triggerPrice: 110,
                baseAmount: 0
            )],
            recentActivity: []
        )

        let ready = reduceReady(
            lifecycle: .open(summary(side: .long, baseSize: 2, marginUsd: 20, entryPrice: 100)),
            extras: extras
        )

        XCTAssertEqual(ready?.orders.first?.actionText, "\(TKLocales.Perps.Asset.sell) 100%")
        XCTAssertEqual(ready?.orders.first?.valueText, PerpsFormatting.signedUsd(20))
        XCTAssertEqual(ready?.orders.first?.percentText, PerpsFormatting.signedPercent(100))
    }

    func test_orders_hiddenWithoutPosition() {
        let extras = PerpsMarketExtras(
            triggerOrders: [PerpsTriggerOrderSummary(orderIndex: 1, kind: .takeProfit, side: .short, triggerPrice: 68141, baseAmount: 1)],
            recentActivity: []
        )
        XCTAssertTrue(reduceReady(lifecycle: .flat, extras: extras)?.orders.isEmpty ?? false)
    }

    func test_restingLimitOrder_isVisibleWithoutPosition() {
        let extras = PerpsMarketExtras(
            limitOrders: [PerpsLimitOrderSummary(
                orderIndex: 9,
                clientOrderIndex: 90,
                side: .long,
                limitPrice: 64000,
                remainingBaseAmount: 0.25
            )],
            triggerOrders: [],
            recentActivity: [],
            flags: flags()
        )

        let ready = reduceReady(lifecycle: .flat, extras: extras)

        XCTAssertEqual(ready?.limitOrders.first?.orderIndex, 9)
        XCTAssertEqual(ready?.limitOrders.first?.priceText, PerpsFormatting.usd(64000))
        XCTAssertEqual(ready?.actions, .longShort(enabled: true))
    }

    func test_autoClose_noOrders_offersSetAutoClose() {
        let ready = reduceReady(lifecycle: .open(summary()), extras: .init(triggerOrders: [], recentActivity: []))
        XCTAssertEqual(ready?.autoClose, .setAutoClose)
        XCTAssertTrue(ready?.orders.isEmpty ?? false)
    }

    func test_autoClose_unknownOrders_offersNothingUntilLoaded() {
        let ready = reduceReady(lifecycle: .open(summary()), extras: nil)
        XCTAssertEqual(ready?.autoClose, PerpsAssetPageViewModel.AutoCloseAffordance.none)
    }

    func test_autoClose_stopLossOnly_offersSetTakeProfit() {
        let extras = PerpsMarketExtras(
            triggerOrders: [PerpsTriggerOrderSummary(orderIndex: 1, kind: .stopLoss, side: .short, triggerPrice: 64720, baseAmount: 1)],
            recentActivity: []
        )
        XCTAssertEqual(reduceReady(lifecycle: .open(summary()), extras: extras)?.autoClose, .setTakeProfit)
    }

    func test_autoClose_bothLegs_offersNothing() {
        let extras = PerpsMarketExtras(
            triggerOrders: [
                PerpsTriggerOrderSummary(orderIndex: 1, kind: .takeProfit, side: .short, triggerPrice: 68141, baseAmount: 1),
                PerpsTriggerOrderSummary(orderIndex: 2, kind: .stopLoss, side: .short, triggerPrice: 64720, baseAmount: 1),
            ],
            recentActivity: []
        )
        let ready = reduceReady(lifecycle: .open(summary()), extras: extras)
        XCTAssertEqual(ready?.orders.count, 2)
        XCTAssertEqual(ready?.autoClose, PerpsAssetPageViewModel.AutoCloseAffordance.none)
    }

    func test_historyBlock_rendersActivity() {
        let extras = PerpsMarketExtras(
            triggerOrders: [],
            recentActivity: [PerpsActivityItem(id: "a1", kind: .trade, marketId: 1, side: .long, baseSize: 1, price: 66000, usdAmount: nil, realizedPnl: 10.25, date: Date(timeIntervalSince1970: 0))]
        )
        let row = reduceReady(lifecycle: .open(summary()), extras: extras)?.history.first
        XCTAssertEqual(row?.title, TKLocales.Perps.Asset.activityClosed(TKLocales.Perps.Asset.short))
        XCTAssertEqual(row?.isAmountPositive, true)
    }

    func test_history_standsAloneWithoutPosition() {
        // A market can have past activity with no currently-open position; history is
        // computed (and rendered) independently of the position block.
        let extras = PerpsMarketExtras(
            triggerOrders: [],
            recentActivity: [PerpsActivityItem(id: "a1", kind: .trade, marketId: 1, side: .long, baseSize: 1, price: 66000, usdAmount: nil, realizedPnl: 10, date: Date(timeIntervalSince1970: 0))]
        )
        let ready = reduceReady(lifecycle: .flat, extras: extras)
        XCTAssertNil(ready?.position)
        XCTAssertEqual(ready?.history.count, 1)
    }

    func test_orderRows_haveDistinctIds_forSamePriceAndSize() {
        // Two TP orders at the same price+size must stay distinct rows — the id is the
        // stable venue order index, not a price/size-derived key.
        let extras = PerpsMarketExtras(
            triggerOrders: [
                PerpsTriggerOrderSummary(orderIndex: 10, kind: .takeProfit, side: .short, triggerPrice: 68000, baseAmount: 1),
                PerpsTriggerOrderSummary(orderIndex: 11, kind: .takeProfit, side: .short, triggerPrice: 68000, baseAmount: 1),
            ],
            recentActivity: []
        )
        let orders = reduceReady(lifecycle: .open(summary(side: .long)), extras: extras)?.orders ?? []
        XCTAssertEqual(orders.count, 2)
        XCTAssertEqual(Set(orders.map(\.id)).count, 2)
    }

    @MainActor
    func test_seeAllHistory_routesMarketId() {
        let (viewModel, _) = makeViewModel(service: MarketsReadingSpy(), marketId: 7)
        var captured: Int64?
        viewModel.onSeeAllHistory = { captured = $0 }
        viewModel.seeAllHistory()
        XCTAssertEqual(captured, 7)
    }

    // MARK: View model — routes

    @MainActor
    func test_long_routesMarketIdAndSide() {
        let (viewModel, _) = makeViewModel(service: MarketsReadingSpy(), marketId: 1)
        var captured: (Int64, PerpsTradeSide)?
        viewModel.onTrade = { captured = ($0, $1) }
        viewModel.long()
        XCTAssertEqual(captured?.0, 1)
        XCTAssertEqual(captured?.1, .long)
    }

    @MainActor
    func test_short_routesMarketIdAndSide() {
        let (viewModel, _) = makeViewModel(service: MarketsReadingSpy(), marketId: 1)
        var captured: (Int64, PerpsTradeSide)?
        viewModel.onTrade = { captured = ($0, $1) }
        viewModel.short()
        XCTAssertEqual(captured?.0, 1)
        XCTAssertEqual(captured?.1, .short)
    }

    @MainActor
    func test_perpetualInfo_andMore_route() {
        let (viewModel, _) = makeViewModel(service: MarketsReadingSpy(), marketId: 1)
        var perpetual = false
        var more = false
        viewModel.onPerpetualInfo = { perpetual = true }
        viewModel.onMore = { more = true }
        viewModel.perpetualInfo()
        viewModel.more()
        XCTAssertTrue(perpetual)
        XCTAssertTrue(more)
    }

    @MainActor
    func test_manageRoutes_carryMarketId() {
        let (viewModel, _) = makeViewModel(service: MarketsReadingSpy(), marketId: 7)
        var edit: Int64?
        var cashOut: Int64?
        var adjustMargin: Int64?
        var autoClose: Int64?
        viewModel.onEdit = { marketId, _ in edit = marketId }
        viewModel.onCashOut = { cashOut = $0 }
        viewModel.onAdjustMargin = { adjustMargin = $0 }
        viewModel.onAutoClose = { autoClose = $0 }
        viewModel.edit()
        viewModel.cashOut()
        viewModel.adjustMargin()
        viewModel.autoClose()
        XCTAssertEqual(edit, 7)
        XCTAssertEqual(cashOut, 7)
        XCTAssertEqual(adjustMargin, 7)
        XCTAssertEqual(autoClose, 7)
    }

    /// Share is gated on an open position (the button only shows then), and emits a
    /// frozen snapshot rather than a route id. With no position it is a no-op.
    @MainActor
    func test_share_withoutPosition_doesNotEmit() {
        let (viewModel, _) = makeViewModel(service: MarketsReadingSpy(), marketId: 7)
        var emitted = false
        viewModel.onShare = { _ in emitted = true }
        viewModel.share()
        XCTAssertFalse(emitted)
    }

    func test_chartMarkers_requiresPositionAndShowsCoreLevels() {
        let opening = PerpsOpeningDescriptor(marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 27, isLimit: false)
        XCTAssertTrue(PerpsAssetPageViewModel.chartMarkers(lifecycle: .opening(opening), extras: nil).isEmpty)
        XCTAssertTrue(PerpsAssetPageViewModel.chartMarkers(lifecycle: .flat, extras: nil).isEmpty)

        let markers = PerpsAssetPageViewModel.chartMarkers(
            lifecycle: .open(summary(entryPrice: 66541.7, liquidationPrice: 64141.75)),
            extras: nil
        )
        XCTAssertEqual(markers.first { $0.kind == .entry }?.price, 66541.7)
        XCTAssertEqual(markers.first { $0.kind == .liquidation }?.price, 64141.75)
        XCTAssertNil(markers.first { $0.kind == .takeProfit })
        XCTAssertNil(markers.first { $0.kind == .stopLoss })
        XCTAssertNil(markers.first { $0.kind == .currentPrice })
    }

    func test_chartMarkers_usesNearestValidTriggers() {
        let extras = PerpsMarketExtras(
            triggerOrders: [
                PerpsTriggerOrderSummary(orderIndex: 0, kind: .takeProfit, side: .short, triggerPrice: 0, baseAmount: 1),
                PerpsTriggerOrderSummary(orderIndex: 1, kind: .takeProfit, side: .short, triggerPrice: 72000, baseAmount: 0.5),
                PerpsTriggerOrderSummary(orderIndex: 2, kind: .takeProfit, side: .short, triggerPrice: 68000, baseAmount: 0.5),
                PerpsTriggerOrderSummary(orderIndex: 3, kind: .stopLoss, side: .short, triggerPrice: -1, baseAmount: 1),
                PerpsTriggerOrderSummary(orderIndex: 4, kind: .stopLoss, side: .short, triggerPrice: 64000, baseAmount: 1),
            ],
            recentActivity: []
        )
        let markers = PerpsAssetPageViewModel.chartMarkers(
            lifecycle: .open(summary(entryPrice: 66541.7)),
            extras: extras
        )
        let tps = markers.filter { $0.kind == .takeProfit }
        XCTAssertEqual(tps.count, 1, "one line per kind")
        XCTAssertEqual(tps.first?.price, 68000, "nearest to entry wins")
        XCTAssertEqual(markers.first { $0.kind == .stopLoss }?.price, 64000)
    }
}

// MARK: - Helpers

private extension PerpsAssetPageViewModelTests {
    @MainActor
    func makeViewModel(
        service: MarketsReadingSpy,
        marketId: Int64,
        account: AccountReadingSpy = AccountReadingSpy(),
        tradingSnapshot: PerpsAssetMarketSnapshot? = nil,
        tradingError: PerpsMarketDetailsLoadError? = nil,
        pricesClient: FakeMarkPricesClient = FakeMarkPricesClient(),
        openPositionFlow: PerpsOpenPositionFlow? = nil
    ) -> (PerpsAssetPageViewModel, PerpsAccountStore) {
        let wallet = Wallet.assetPageTest()
        let store = PerpsMarketsStore.makeForTests(
            service: service,
            tickers: [marketId: "BTC/USD"],
            client: pricesClient
        )
        let accountStore = PerpsAccountStore(service: account, wallet: wallet)
        let viewModel = PerpsAssetPageViewModel(
            marketId: marketId,
            store: store,
            marketDetailsStore: marketDetailsStore(
                snapshot: tradingSnapshot ?? makeSnapshot(),
                error: tradingError
            ),
            accountStore: accountStore,
            openPositionFlow: openPositionFlow ?? PerpsOpenPositionFlow()
        )
        trackedViewModels.append(viewModel)
        return (viewModel, accountStore)
    }

    func marketDetailsStore(
        snapshot: PerpsAssetMarketSnapshot,
        error: PerpsMarketDetailsLoadError? = nil
    ) -> PerpsMarketDetailsStore {
        let spy = MarketDetailsLoadingSpy()
        spy.snapshot = snapshot
        spy.error = error
        return PerpsMarketDetailsStore(service: spy)
    }

    // MARK: Pure-mapping helpers (no stores)

    /// Runs the view model's pure reducer over a loaded market + the given lifecycle/
    /// extras, returning the resulting `Ready`. No async, no live stores.
    func reduceReady(
        lifecycle: PerpsMarketLifecycle,
        extras: PerpsMarketExtras? = nil,
        markPrice: Double = 66141,
        tradingEnabled: Bool = true,
        isAccountActive: Bool = true,
        isOpenPositionSubmitting: Bool = false
    ) -> PerpsAssetPageViewModel.Ready? {
        PerpsAssetPageViewModel.reduce(
            market: .ready(snapshot: makeSnapshot(tradingEnabled: tradingEnabled), markPrice: markPrice, sizeDecimals: 2),
            lifecycle: lifecycle,
            extras: extras,
            isAccountActive: isAccountActive,
            isOpenPositionSubmitting: isOpenPositionSubmitting,
            previous: .loading
        ).ready
    }

    func flags(
        openEnabled: Bool? = true,
        closeEnabled: Bool? = true,
        cancelEnabled: Bool? = true,
        addMarginEnabled: Bool? = true,
        removeMarginEnabled: Bool? = true,
        autoCloseEnabled: Bool? = true
    ) -> PerpsTradingFlags {
        PerpsTradingFlags(
            openEnabled: openEnabled,
            closeEnabled: closeEnabled,
            cancelEnabled: cancelEnabled,
            addMarginEnabled: addMarginEnabled,
            removeMarginEnabled: removeMarginEnabled,
            autoCloseEnabled: autoCloseEnabled
        )
    }

    func extras(flags: PerpsTradingFlags?, autoCloseKnown: Bool = true) -> PerpsMarketExtras {
        PerpsMarketExtras(
            limitOrders: [],
            triggerOrders: [],
            recentActivity: [],
            flags: flags,
            autoCloseKnown: autoCloseKnown
        )
    }

    func makeSnapshot(tradingEnabled: Bool = true) -> PerpsAssetMarketSnapshot {
        PerpsAssetMarketSnapshot(
            marketId: 1, symbol: "BTC", displayName: "BTC",
            status: tradingEnabled ? "active" : "paused", maxLeverage: 40, priceDecimals: 2,
            sizeDecimals: 2,
            price: 66141, priceChangePercent: 4.37, priceChangeAmount: 100,
            volume24h: 2_360_000_000, openInterest: 1_700_000_000, fundingRatePercent: nil, about: nil,
            openEnabled: tradingEnabled
        )
    }

    func summary(
        marketId: Int64 = 1,
        symbol: String = "BTC",
        side: KeeperCore.PerpsTradeSide = .long,
        baseSize: Double = 1,
        notionalUsd: Double = 540,
        marginUsd: Double = 20,
        equityUsd: Double = 20.5,
        leverage: Double? = 27,
        roiPercent: Double? = 2.5,
        entryPrice: Double = 66541.7,
        liquidationPrice: Double = 64141.75,
        unrealizedPnlUsd: Double = 0.5,
        fundingPaidUsd: Double? = 0,
        liquidationDistancePercent: Double? = -3.02
    ) -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:\(marketId)",
            marketId: marketId, symbol: symbol, side: side, baseSize: baseSize,
            notionalUsd: notionalUsd, marginUsd: marginUsd, equityUsd: equityUsd,
            leverage: leverage, roiPercent: roiPercent, entryPrice: entryPrice,
            liquidationPrice: liquidationPrice, unrealizedPnlUsd: unrealizedPnlUsd,
            realizedPnlUsd: 0, fundingPaidUsd: fundingPaidUsd,
            liquidationDistancePercent: liquidationDistancePercent
        )
    }

    func makeMarket(
        id: Int64 = 1,
        symbol: String = "BTC",
        status: String = "active",
        lastTradePrice: Double = 100,
        dailyPriceChange: Double = 4.37,
        fundingRatePercent: Double? = nil
    ) -> PerpsMarketMetadata {
        PerpsMarketMetadata(
            marketId: id,
            symbol: symbol,
            ticker: "\(symbol)/USD",
            status: status,
            markPrice: nil,
            lastTradePrice: lastTradePrice,
            priceChangePercent: dailyPriceChange,
            volume24h: 2_360_000_000,
            openInterest: 1_700_000_000,
            maxLeverage: 40,
            fundingRatePercent: fundingRatePercent,
            priceDecimals: 2,
            sizeDecimals: 2,
            minBaseSize: 0
        )
    }

    func makeSummary(
        side: PerpsTradeSide = .long,
        entryPrice: Double = 66541.7,
        notionalUsd: Double = 540,
        marginUsd: Double = 20,
        equityUsd: Double = 20.5,
        leverage: Double? = 27,
        roiPercent: Double? = 2.5,
        unrealizedPnlUsd: Double = 0.5
    ) -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:1",
            marketId: 1,
            symbol: "BTC",
            side: side,
            baseSize: 0.5,
            notionalUsd: notionalUsd,
            marginUsd: marginUsd,
            equityUsd: equityUsd,
            leverage: leverage,
            roiPercent: roiPercent,
            entryPrice: entryPrice,
            liquidationPrice: 64141.75,
            unrealizedPnlUsd: unrealizedPnlUsd,
            realizedPnlUsd: 0,
            fundingPaidUsd: 0
        )
    }

    func makeTrigger(orderIndex: Int64, clientOrderIndex: Int64) -> PerpsTriggerOrderSummary {
        PerpsTriggerOrderSummary(
            orderIndex: orderIndex,
            clientOrderIndex: clientOrderIndex,
            kind: .takeProfit,
            side: .short,
            triggerPrice: 68000,
            baseAmount: 0
        )
    }

    func makeActivity(kind: PerpsActivityItem.Kind, realizedPnl: Double? = nil) -> PerpsActivityItem {
        PerpsActivityItem(
            id: "act-1",
            kind: kind,
            marketId: 1,
            side: .short,
            baseSize: 1,
            price: 66000,
            usdAmount: nil,
            realizedPnl: realizedPnl,
            date: Date(timeIntervalSince1970: 0)
        )
    }

    /// Event-driven wait: re-checks `condition` on every view-model change
    /// (`objectWillChange`), fulfilling as soon as it holds. This integrates with the
    /// XCTest run loop instead of busy-polling with `Task.sleep`, which on `@MainActor`
    /// could starve the store's resolve→recompute hop and time out nondeterministically.
    @MainActor
    func waitUntil(
        _ viewModel: PerpsAssetPageViewModel,
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

    func waitUntilStore(
        _ store: PerpsMarketDetailsStore,
        timeout: TimeInterval = 5,
        _ condition: @escaping (PerpsMarketDetailsStore.State) -> Bool
    ) async {
        let fulfilled = XCTestExpectation(description: "market details store condition")
        fulfilled.assertForOverFulfill = false
        store.addObserver(self) { _, event in
            if case let .didUpdate(state) = event, condition(state) {
                fulfilled.fulfill()
            }
        } onRegistered: {
            if condition(store.getState()) {
                fulfilled.fulfill()
            }
        }
        await fulfillment(of: [fulfilled], timeout: timeout)
    }
}

private extension Wallet {
    static func assetPageTest() -> Wallet {
        let raw = Data("perps-asset-test-public-key".utf8)
        let padded = raw + Data(repeating: 0, count: max(0, 32 - raw.count))
        let publicKey = TonSwift.PublicKey(data: Data(padded.prefix(32)))
        return Wallet(
            id: "perps-asset-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Perps Asset Test", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                .init(
                    walletId: "perps-asset-test-wallet-id",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0x1")]
                )
            )
        )
    }
}

private final class MarketDetailsLoadingSpy: PerpsMarketDetailsLoading, @unchecked Sendable {
    var snapshot: PerpsAssetMarketSnapshot?
    var error: PerpsMarketDetailsLoadError?

    func load(marketId _: Int64) async throws -> PerpsAssetMarketSnapshot {
        if let error {
            throw error
        }
        guard let snapshot else {
            throw PerpsMarketDetailsLoadError.failed
        }
        return snapshot
    }
}

private final class MarketsReadingSpy: PerpsMarketsReading, @unchecked Sendable {
    var marketsResult: [PerpsMarketSummary] = []

    func markets(query _: String?, sort _: PerpsMarketsSort, cursor _: String?) async throws -> PerpsMarketsPage {
        .test(marketsResult)
    }

    func marketDetails(marketId _: Int64) async throws -> PerpsMarketDetails {
        throw PerpsMarketsRepositoryError.marketNotFound
    }
}

/// Active-account double that captures the live positions `onUpdate` so a test can
/// push streamed positions through the store.
private final class LivePositionsAccountSpy: PerpsAccountReading, @unchecked Sendable {
    let accountIndex: Int64 = 7
    let watchOpened = XCTestExpectation(description: "positions watch opened")
    private(set) var capturedOnUpdate: (@Sendable ([PerpsPositionSummary]) -> Void)?

    func status(wallet: Wallet) async -> PerpsAccountStatus {
        .account(accountIndex: accountIndex)
    }

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot? {
        PerpsAccountSnapshot(availableBalance: "1000")
    }

    func tradingSnapshot(wallet: Wallet, marketId: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
    }

    func recentActivity(wallet: Wallet, marketId: Int64, limit: Int) async throws -> [PerpsActivityItem] {
        []
    }

    func watchPositions(
        wallet: Wallet,
        onUpdate: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        capturedOnUpdate = onUpdate
        watchOpened.fulfill()
        return PerpsPositionsWatch {}
    }
}

/// No-account double — enough for the markets-only integration tests (account
/// resolves to inactive). Position/lifecycle behaviour is covered by the pure
/// `reduce` tests, so the spy no longer needs to vend portfolios/orders/activity.
private final class AccountReadingSpy: PerpsAccountReading, @unchecked Sendable {
    func status(wallet: Wallet) async -> PerpsAccountStatus {
        .noAccount(ethAddress: "0x0")
    }

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot? {
        nil
    }

    func tradingSnapshot(wallet: Wallet, marketId: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
    }

    func recentActivity(wallet: Wallet, marketId: Int64, limit: Int) async throws -> [PerpsActivityItem] {
        []
    }

    func watchPositions(
        wallet: Wallet,
        onUpdate: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onInterrupted: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        PerpsPositionsWatch {}
    }
}

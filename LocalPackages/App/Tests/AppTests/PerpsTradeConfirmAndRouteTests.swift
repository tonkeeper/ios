@testable import App
import ChainKit
import Combine
@testable import KeeperCore
import TKLocalize
import TonSwift
import XCTest

@MainActor
final class PerpsTradeConfirmAndRouteTests: XCTestCase {
    // MARK: Confirm rows (SDK preview, no signing prepare)

    func test_confirm_rendersPreviewEntryLiquidationAndFee() {
        let viewModel = PerpsTradeConfirmViewModel(
            context: FakePerpsTradingService.makeConfirmContext()
        )
        XCTAssertTrue(viewModel.titleText.contains("BTC"))
        let entry = viewModel.rows.first { $0.title == TKLocales.Perps.Confirm.entryPrice }
        XCTAssertEqual(entry?.value, PerpsFormatting.usd(66541.70))
        let liquidation = viewModel.rows.first { $0.title == TKLocales.Perps.Confirm.liquidation }
        XCTAssertEqual(liquidation?.value, PerpsFormatting.usd(64141.75))
        let fee = viewModel.rows.first { $0.title == TKLocales.Perps.Confirm.fee }
        XCTAssertEqual(fee?.value, PerpsFormatting.usd(0.27))
    }

    func test_confirm_liquidationUnavailable_showsUnavailableNotZero() {
        let viewModel = PerpsTradeConfirmViewModel(
            context: FakePerpsTradingService.makeConfirmContext(
                review: FakePerpsTradingService.makeReview(liquidationPrice: nil)
            )
        )
        let liquidation = viewModel.rows.first { $0.title == TKLocales.Perps.Confirm.liquidation }
        XCTAssertEqual(liquidation?.value, TKLocales.Perps.Confirm.unavailable)
    }

    func test_confirm_noPrice_showsEntryUnavailable() {
        let viewModel = PerpsTradeConfirmViewModel(
            context: FakePerpsTradingService.makeConfirmContext(
                review: FakePerpsTradingService.makeReview(entryPrice: nil)
            )
        )
        let entry = viewModel.rows.first { $0.title == TKLocales.Perps.Confirm.entryPrice }
        XCTAssertEqual(entry?.value, TKLocales.Perps.Confirm.unavailable)
    }

    func test_confirm_limitOrder_entryUsesStaticLimitPrice() {
        let intent = FakePerpsTradingService.makeIntent(limitPrice: 65000)
        let viewModel = PerpsTradeConfirmViewModel(
            context: FakePerpsTradingService.makeConfirmContext(
                intent: intent,
                review: FakePerpsTradingService.makeReview(entryPrice: 65000, liquidationPrice: 63000)
            )
        )
        let entry = viewModel.rows.first { $0.title == TKLocales.Perps.Confirm.entryPrice }
        XCTAssertEqual(entry?.value, PerpsFormatting.usd(65000))
    }

    // MARK: Cash Out confirm

    func test_closeConfirm_buildsTitleAndRowsFromReview() {
        let viewModel = PerpsTradeConfirmViewModel(closeContext: Self.makeCloseContext())
        XCTAssertEqual(viewModel.titleText, "\(TKLocales.Perps.Confirm.close) \(TKLocales.Perps.Asset.long) BTC")
        XCTAssertEqual(viewModel.rows.map(\.id), [.position, .leverage, .size, .fee, .pnl, .youReceive])
        let pnl = viewModel.rows.first { $0.id == .pnl }
        XCTAssertEqual(pnl?.value, PerpsFormatting.signedUsd(0.5))
        XCTAssertEqual(pnl?.tone, .positive)
        let receive = viewModel.rows.first { $0.id == .youReceive }
        XCTAssertEqual(receive?.value, PerpsFormatting.usd(20.34))
    }

    func test_closeConfirm_lossTintsNegative_missingEstimatesShowUnavailable() {
        let loss = PerpsTradeConfirmViewModel(
            closeContext: Self.makeCloseContext(review: FakePerpsTradingService.makeCloseReview(estimatedPnlUsd: -1.2))
        )
        XCTAssertEqual(loss.rows.first { $0.id == .pnl }?.tone, .negative)

        let unavailable = PerpsTradeConfirmViewModel(
            closeContext: Self.makeCloseContext(review: FakePerpsTradingService.makeCloseReview(
                leverage: nil,
                marginUsd: 0,
                estimatedFeeUsd: nil,
                estimatedPnlUsd: nil,
                estimatedReceiveUsd: nil
            ))
        )
        for kind in [PerpsTradeConfirmViewModel.Row.Kind.leverage, .fee, .pnl, .youReceive] {
            let row = unavailable.rows.first { $0.id == kind }
            XCTAssertEqual(row?.value, TKLocales.Perps.Confirm.unavailable, "\(kind)")
            XCTAssertEqual(row?.tone, .neutral, "\(kind)")
        }
    }

    private static func makeCloseContext(
        review: PerpsCloseReview = FakePerpsTradingService.makeCloseReview()
    ) -> PerpsCloseConfirmContext {
        PerpsCloseConfirmContext(sizeDecimals: 5, review: review)
    }

    // MARK: Size-change confirm

    func test_sizeChangeConfirm_add_rendersOldToNewAndSignedBaseDelta() {
        let viewModel = makeSizeChangeConfirmViewModel(
            autoClose: PerpsAutoClose(triggerOrders: [
                PerpsTriggerOrderSummary(orderIndex: 1, kind: .takeProfit, side: .short, triggerPrice: 68141, baseAmount: 0.008),
            ])
        )
        XCTAssertEqual(viewModel.titleText, TKLocales.Perps.EditPosition.addTitle("\(TKLocales.Perps.Asset.long) BTC"))
        XCTAssertEqual(viewModel.rows.map(\.id), [.youPay, .entry, .leverage, .liquidation, .size, .fee, .autoClose])

        let entry = viewModel.rows.first { $0.id == .entry }
        XCTAssertEqual(entry?.value, "\(PerpsFormatting.usd(66541.70)) → \(PerpsFormatting.usd(66021.17))")

        let size = viewModel.rows.first { $0.id == .size }
        XCTAssertEqual(size?.value, "\(PerpsFormatting.usd(540)) → \(PerpsFormatting.usd(1080))")
        XCTAssertEqual(size?.subValue, "+\(PerpsFormatting.token(0.0083, symbol: "BTC", decimals: 5))")

        let autoClose = viewModel.rows.first { $0.id == .autoClose }
        XCTAssertEqual(
            autoClose?.value,
            "\(TKLocales.Perps.OpenPosition.tp) \(PerpsFormatting.usd(68141))"
        )
        XCTAssertEqual(autoClose?.showsChevron, true)
        XCTAssertEqual(autoClose?.valueParts?.map(\.tone), [.neutral])
    }

    func test_sizeChangeConfirm_reduce_showsYouCloseAndPlainEntry() {
        let viewModel = makeSizeChangeConfirmViewModel(
            review: FakePerpsTradingService.makeSizeChangeReview(
                direction: .reduce,
                entryPrice: PerpsValueChange(old: 66541.70, new: 66541.70),
                notionalUsd: PerpsValueChange(old: 540, new: 270),
                baseSize: PerpsValueChange(old: 0.008, new: 0.004)
            )
        )
        XCTAssertEqual(viewModel.titleText, TKLocales.Perps.EditPosition.reduceTitle("\(TKLocales.Perps.Asset.long) BTC"))

        let youClose = viewModel.rows.first { $0.id == .youClose }
        XCTAssertEqual(youClose?.title, TKLocales.Perps.Confirm.youClose)

        let entry = viewModel.rows.first { $0.id == .entry }
        XCTAssertEqual(entry?.value, PerpsFormatting.usd(66541.70))

        let size = viewModel.rows.first { $0.id == .size }
        XCTAssertEqual(size?.subValue, "−\(PerpsFormatting.token(0.004, symbol: "BTC", decimals: 5))")
        XCTAssertNil(viewModel.rows.first { $0.id == .autoClose })
    }

    func test_sizeChangeConfirm_rendersAbsoluteAutoCloseTarget() {
        let viewModel = makeSizeChangeConfirmViewModel(
            autoClose: PerpsAutoClose(
                takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
                stopLoss: nil
            )
        )
        let autoClose = viewModel.rows.first { $0.id == .autoClose }
        XCTAssertEqual(
            autoClose?.value,
            "\(TKLocales.Perps.OpenPosition.tp) \(PerpsFormatting.usd(70000))"
        )
    }

    func test_sizeChangeConfirm_keepsPreparedRestingSnapshot() async {
        let initial = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 68141),
            stopLoss: nil
        )
        let session = FakePerpsTradingService.makeReviewingSizeChangeSession(autoClose: initial)
        guard let viewModel = PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: 5
        ) else {
            return XCTFail("reviewing session must make a confirm view model")
        }
        let updatedPrice = 70000.0
        let initialValue = viewModel.rows.first { $0.id == .autoClose }?.value

        session.updateRestingTriggerOrders([
            PerpsTriggerOrderSummary(
                orderIndex: 2,
                kind: .takeProfit,
                side: .short,
                triggerPrice: updatedPrice,
                baseAmount: 0.008
            ),
        ])

        await Task.yield()
        XCTAssertEqual(
            viewModel.rows.first { $0.id == .autoClose }?.value,
            initialValue
        )
    }

    func test_sizeChangeConfirm_tracksImmutableProjectionAcrossReprepare() async throws {
        let resting = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 68141),
            stopLoss: nil
        )
        let edited = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
            stopLoss: nil
        )
        let session = FakePerpsTradingService.makeReviewingSizeChangeSession(autoClose: resting)
        let viewModel = try XCTUnwrap(PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: 5
        ))
        let review = try XCTUnwrap(session.prepared?.review)
        let initialValue = viewModel.rows.first { $0.id == .autoClose }?.value
        var confirmed = false
        viewModel.onConfirm = { confirmed = true }

        let request = try XCTUnwrap(session.beginRepreparation(desiredAutoClose: edited))
        await Task.yield()
        viewModel.confirm()

        XCTAssertFalse(viewModel.isConfirmationEnabled)
        XCTAssertFalse(confirmed)
        XCTAssertEqual(viewModel.rows.first { $0.id == .autoClose }?.value, initialValue)

        let prepared = PerpsPreparedSizeChangeAction(
            operationId: "reprepared",
            walletId: "wallet",
            marketId: 1,
            intent: request.intent,
            review: review,
            normalizedAutoClose: edited
        )
        XCTAssertTrue(session.acceptPreparation(prepared, for: request))
        await Task.yield()
        XCTAssertTrue(viewModel.isConfirmationEnabled)
        viewModel.confirm()

        XCTAssertTrue(confirmed)
        XCTAssertEqual(
            viewModel.rows.first { $0.id == .autoClose }?.value,
            "\(TKLocales.Perps.OpenPosition.tp) \(PerpsFormatting.usd(70000))"
        )
    }

    func test_confirm_autoClose_marksStaleTakeProfitNegative() {
        let intent = FakePerpsTradingService.makeIntent(
            autoClose: PerpsAutoClose(
                takeProfit: PerpsAutoCloseTrigger(triggerPrice: 59500),
                stopLoss: PerpsAutoCloseTrigger(triggerPrice: 55000)
            )
        )
        let viewModel = PerpsTradeConfirmViewModel(
            context: FakePerpsTradingService.makeConfirmContext(
                intent: intent,
                review: FakePerpsTradingService.makeReview(entryPrice: 66000, liquidationPrice: 50000)
            )
        )
        let autoClose = viewModel.rows.first { $0.id == .autoClose }
        XCTAssertEqual(autoClose?.valueParts?.map(\.tone), [.negative, .tertiary, .neutral])
        XCTAssertTrue(autoClose?.showsChevron == true)
    }

    func test_marginChangeConfirm_add_rendersYouPayAndLiquidationChange_withoutFee() {
        let viewModel = PerpsTradeConfirmViewModel(marginChangeContext: PerpsMarginChangeConfirmContext(
            review: FakePerpsTradingService.makeMarginChangeReview()
        ))
        XCTAssertEqual(viewModel.titleText, TKLocales.Perps.AdjustMargin.addConfirmTitle("\(TKLocales.Perps.Asset.long) BTC"))
        XCTAssertEqual(viewModel.rows.map(\.id), [.youPay, .liquidation])

        let youPay = viewModel.rows.first { $0.id == .youPay }
        XCTAssertEqual(youPay?.value, PerpsFormatting.usd(20))

        let liquidation = viewModel.rows.first { $0.id == .liquidation }
        XCTAssertEqual(liquidation?.value, "\(PerpsFormatting.usd(64141.75)) → \(PerpsFormatting.usd(63639.99))")
    }

    func test_marginChangeConfirm_reduce_showsYouClose_andUnavailableLiquidation() {
        let viewModel = PerpsTradeConfirmViewModel(marginChangeContext: PerpsMarginChangeConfirmContext(
            review: FakePerpsTradingService.makeMarginChangeReview(
                direction: .reduce,
                amountUsd: 10,
                allocatedMargin: PerpsValueChange(old: 20, new: 10),
                liquidationPrice: nil
            )
        ))
        XCTAssertEqual(viewModel.titleText, TKLocales.Perps.AdjustMargin.reduceConfirmTitle("\(TKLocales.Perps.Asset.long) BTC"))

        let youClose = viewModel.rows.first { $0.id == .youClose }
        XCTAssertEqual(youClose?.title, TKLocales.Perps.Confirm.youClose)
        XCTAssertEqual(youClose?.value, PerpsFormatting.usd(10))

        let liquidation = viewModel.rows.first { $0.id == .liquidation }
        XCTAssertEqual(liquidation?.value, TKLocales.Perps.Confirm.unavailable)
    }

    // MARK: Confirm swipe

    func test_confirm_swipe_invokesOnConfirm_withoutPreparing() {
        let viewModel = PerpsTradeConfirmViewModel(context: FakePerpsTradingService.makeConfirmContext())
        var confirmed = false
        viewModel.onConfirm = { confirmed = true }
        viewModel.confirm()
        XCTAssertTrue(confirmed)
    }

    private func makeSizeChangeConfirmViewModel(
        review: PerpsSizeChangeReview = FakePerpsTradingService.makeSizeChangeReview(),
        autoClose: PerpsAutoClose? = nil
    ) -> PerpsTradeConfirmViewModel {
        let session = FakePerpsTradingService.makeReviewingSizeChangeSession(
            review: review,
            autoClose: autoClose
        )
        guard let viewModel = PerpsTradeConfirmViewModel(
            sizeChangeSession: session,
            sizeDecimals: 5
        ) else {
            preconditionFailure("reviewing session must make a confirm view model")
        }
        return viewModel
    }

    // MARK: Asset Page routing

    func test_assetPage_long_routesWithMarketIdAndLongSide() {
        let viewModel = PerpsAssetPageViewModel(
            marketId: 42,
            store: PerpsMarketsStore.makeUnsubscribed(),
            marketDetailsStore: PerpsMarketDetailsStore.makeFailingLoad(),
            accountStore: PerpsAccountStore.makeStub(),
            openPositionFlow: PerpsOpenPositionFlow()
        )
        var captured: (Int64, PerpsTradeSide)?
        viewModel.onTrade = { captured = ($0, $1) }
        viewModel.long()
        XCTAssertEqual(captured?.0, 42)
        XCTAssertEqual(captured?.1, .long)
    }

    func test_assetPage_short_routesWithShortSide() {
        let viewModel = PerpsAssetPageViewModel(
            marketId: 7,
            store: PerpsMarketsStore.makeUnsubscribed(),
            marketDetailsStore: PerpsMarketDetailsStore.makeFailingLoad(),
            accountStore: PerpsAccountStore.makeStub(),
            openPositionFlow: PerpsOpenPositionFlow()
        )
        var captured: (Int64, PerpsTradeSide)?
        viewModel.onTrade = { captured = ($0, $1) }
        viewModel.short()
        XCTAssertEqual(captured?.1, .short)
    }

    // MARK: Trade toast lifecycle

    func test_toast_progressFromLifecycle_thenTerminalSuccess() async {
        let accountStore = PerpsAccountStore.makeStub()
        let viewModel = PerpsAssetPageViewModel(
            marketId: 1,
            store: PerpsMarketsStore.makeUnsubscribed(),
            marketDetailsStore: PerpsMarketDetailsStore.makeFailingLoad(),
            accountStore: accountStore,
            openPositionFlow: PerpsOpenPositionFlow()
        )
        // The opening progress is driven by the store lifecycle, not the view model,
        // so it survives leaving the Asset Page. The store notifies asynchronously.
        accountStore.beginOpening(PerpsOpeningDescriptor(
            marketId: 1, symbol: "BTC", side: .long, marginUsd: 20, leverage: 27, isLimit: false
        ))
        // Event-driven: re-check on each view-model change instead of busy-polling.
        await waitUntil(viewModel) {
            if case .progress = viewModel.tradeToast { return true }
            return false
        }
        guard case .progress = viewModel.tradeToast else {
            return XCTFail("expected progress toast while opening")
        }
        // A terminal success takes precedence over the lifecycle progress for its beat.
        viewModel.showTradeResult(.success("Opened BTC long: $20 · 27x"))
        XCTAssertEqual(viewModel.tradeToast, .success("Opened BTC long: $20 · 27x"))
    }

    /// Margin pills are amount-based ("Adding $20 margin"), unlike the size
    /// pills' "symbol side · leverage" pattern — locked to the design nodes.
    func test_marginLifecycleToast_usesAmountBasedCopy() {
        let summary = PerpsPositionSummary(
            positionId: "lighter:1",
            marketId: 1, symbol: "BTC", side: .long, baseSize: 0.008, notionalUsd: 540,
            marginUsd: 20, equityUsd: 20.5, leverage: 27, roiPercent: 2.5, entryPrice: 66000, liquidationPrice: 64141.75,
            unrealizedPnlUsd: 0.5, realizedPnlUsd: 0, fundingPaidUsd: nil
        )
        XCTAssertEqual(
            PerpsAssetPageViewModel.lifecycleToast(.adjustingMargin(summary, .add, amountUsd: 20)),
            .progress(TKLocales.Perps.Toast.marginAdding(PerpsFormatting.usd(20)))
        )
        XCTAssertEqual(
            PerpsAssetPageViewModel.lifecycleToast(.adjustingMargin(summary, .reduce, amountUsd: 10)),
            .progress(TKLocales.Perps.Toast.marginReducing(PerpsFormatting.usd(10)))
        )
        XCTAssertEqual(
            PerpsAssetPageViewModel.marginToastText(direction: .add, amountUsd: 20, isDone: true),
            TKLocales.Perps.Toast.marginAdded(PerpsFormatting.usd(20))
        )
        XCTAssertEqual(
            PerpsAssetPageViewModel.marginToastText(direction: .reduce, amountUsd: 10, isDone: true),
            TKLocales.Perps.Toast.marginReduced(PerpsFormatting.usd(10))
        )
    }
}

private extension PerpsMarketDetailsStore {
    static func makeFailingLoad() -> PerpsMarketDetailsStore {
        PerpsMarketDetailsStore(service: FailingMarketDetailsLoading())
    }
}

private final class FailingMarketDetailsLoading: PerpsMarketDetailsLoading {
    func load(marketId _: Int64) async throws -> PerpsAssetMarketSnapshot {
        throw PerpsMarketDetailsLoadError.failed
    }
}

private extension PerpsMarketsStore {
    static func makeUnsubscribed() -> PerpsMarketsStore {
        .makeForTests(service: NoopMarketsReading())
    }
}

private extension PerpsTradeConfirmAndRouteTests {
    /// Event-driven wait: re-checks `condition` on every view-model change
    /// (`objectWillChange`), fulfilling as soon as it holds — no busy-polling.
    func waitUntil(
        _ viewModel: PerpsAssetPageViewModel,
        timeout: TimeInterval = 5,
        _ condition: @escaping () -> Bool
    ) async {
        if condition() { return }
        let fulfilled = XCTestExpectation(description: "view model condition")
        fulfilled.assertForOverFulfill = false
        let cancellable = viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in if condition() { fulfilled.fulfill() } }
        await fulfillment(of: [fulfilled], timeout: timeout)
        cancellable.cancel()
    }
}

private extension PerpsAccountStore {
    static func makeStub() -> PerpsAccountStore {
        PerpsAccountStore(service: NoopAccountReading(), wallet: makeConfirmRouteWallet())
    }
}

private func makeConfirmRouteWallet() -> Wallet {
    let raw = Data("perps-confirm-test-public-key".utf8)
    let padded = raw + Data(repeating: 0, count: max(0, 32 - raw.count))
    let publicKey = TonSwift.PublicKey(data: Data(padded.prefix(32)))
    return Wallet(
        id: "perps-confirm-test",
        identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
        metaData: WalletMetaData(label: "Perps Confirm Test", tintColor: .SteelGray, icon: .icon(.wallet)),
        setupSettings: WalletSetupSettings(),
        batterySettings: BatterySettings()
    )
}

private final class NoopAccountReading: PerpsAccountReading {
    func status(wallet _: Wallet) async -> PerpsAccountStatus {
        .noAccount(ethAddress: "0x0")
    }

    func portfolio(wallet _: Wallet) async throws -> PerpsAccountSnapshot? {
        nil
    }

    func tradingSnapshot(wallet _: Wallet, marketId _: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: []))
    }

    func recentActivity(wallet _: Wallet, marketId _: Int64, limit _: Int) async throws -> [PerpsActivityItem] {
        []
    }

    func watchPositions(
        wallet _: Wallet,
        onUpdate _: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onInterrupted _: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        PerpsPositionsWatch {}
    }
}

private final class NoopMarketsReading: PerpsMarketsReading {
    func markets(query _: String?, sort _: PerpsMarketsSort, cursor _: String?) async throws -> PerpsMarketsPage {
        .test([])
    }

    func marketDetails(marketId _: Int64) async throws -> PerpsMarketDetails {
        throw PerpsMarketsRepositoryError.marketNotFound
    }
}

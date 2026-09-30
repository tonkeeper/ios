@testable import App
import ChainKit
import Combine
@testable import KeeperCore
import TonSwift
import XCTest

@MainActor
final class PerpsOpenPositionViewModelTests: XCTestCase {
    private func makeViewModel(
        side: PerpsTradeSide = .long,
        service: FakePerpsTradingService = FakePerpsTradingService(),
        status: PerpsAccountStatus = .account(accountIndex: 1),
        balance: String = "712.56"
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
            initialLeverage: 10
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
        XCTAssertEqual(viewModel.balanceText, PerpsFormatting.usd(712.56))
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
        XCTAssertFalse(viewModel.isReviewEnabled)
    }

    func test_max_fillsAvailableBalance() async {
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { accountIsReady(viewModel) }
        viewModel.setMax()
        XCTAssertEqual(viewModel.marginUsd, 712.56, accuracy: 1e-6)
    }

    func test_orderRetriesBalanceAfterInitialPortfolioFailure() async {
        let reader = AccountReadingSpy()
        reader.statusResult = .account(accountIndex: 1)
        reader.portfolioError = AccountReadingError.failed
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
        XCTAssertEqual(reader.portfolioCallCount, 1)

        reader.portfolioError = nil
        reader.portfolioResult = PerpsAccountSnapshot(availableBalance: "321.45")
        let viewModel = PerpsOpenPositionViewModel(
            marketId: 1,
            side: .long,
            service: FakePerpsTradingService(),
            accountStore: store,
            initialLeverage: 10
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
        XCTAssertEqual(reader.portfolioCallCount, 2)
        XCTAssertEqual(viewModel.balanceText, PerpsFormatting.usd(321.45))
    }

    // MARK: - Review gating

    func test_review_disabled_whenBelowMinimumSize() async {
        // Context: minBaseSize 0.0001, price 66_141.70. A $0.1 margin at 27x is ~2.7 USD
        // notional → baseSize ~0.0000408, below the minimum. Review is simply disabled (no
        // inline copy — Figma has no validation message).
        let viewModel = makeViewModel()
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.applyLeverage(27)
        viewModel.setAmount("0.1")
        XCTAssertFalse(viewModel.isReviewEnabled)
        // A real-sized order clears the minimum and Review enables.
        viewModel.setAmount("20")
        XCTAssertTrue(viewModel.isReviewEnabled)
    }

    func test_noPrice_blocksReview() async {
        // Neither mark nor last-trade is known (displayPrice 0): we can't size the order, so
        // Review is disabled and the header shows "—". Regression for the `Price —` screenshot.
        let service = FakePerpsTradingService()
        service.context = FakePerpsTradingService.makeContext(displayPrice: 0)
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("50000")
        XCTAssertEqual(viewModel.headerPriceText, "—")
        XCTAssertFalse(viewModel.isReviewEnabled)
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

    func test_review_doesNotAskForAPasscode() async {
        let service = FakePerpsTradingService()
        let viewModel = makeViewModel(service: service)
        viewModel.onAppear()
        await waitUntil(viewModel) { viewModel.viewState == .ready && accountIsReady(viewModel) }
        viewModel.setAmount("20")

        let reviewed = XCTestExpectation(description: "review emitted")
        viewModel.onReview = { _ in reviewed.fulfill() }
        viewModel.review()

        await fulfillment(of: [reviewed], timeout: 5)
        XCTAssertFalse(service.passcodeRequested)
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
        XCTAssertEqual(viewModel.headerPriceText, PerpsFormatting.usd(66141.70))

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
            "The Stop Loss value must be above the liquidation price (\(PerpsFormatting.usd(65500)))."
        )
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
    var portfolioError: Error?
    private(set) var portfolioCallCount = 0

    func status(wallet: Wallet) async -> PerpsAccountStatus {
        statusResult
    }

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot? {
        portfolioCallCount += 1
        if let portfolioError {
            throw portfolioError
        }
        return portfolioResult
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

private enum AccountReadingError: Error {
    case failed
}

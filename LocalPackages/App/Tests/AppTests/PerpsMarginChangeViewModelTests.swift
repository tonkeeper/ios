@testable import App
import ChainKit
@testable import KeeperCore
@testable import Perps
import PerpsModels
import TKLocalize
import TonSwift
import XCTest

@MainActor
final class PerpsMarginChangeViewModelTests: XCTestCase {
    private static let limits = PerpsMarginChangeLimits(minUsd: 1, maxReduceUsd: 2.97)

    /// BTC long: 0.008 @ $66 000, margin $20, liq $64 141.75.
    private func makeViewModel(
        direction: PerpsMarginChangeDirection,
        service: FakePerpsTradingService = FakePerpsTradingService(),
        marketsStore: PerpsMarketsStore = .makeForTests(),
        limits: PerpsMarginChangeLimits? = nil
    ) async -> (viewModel: PerpsMarginChangeViewModel, service: FakePerpsTradingService) {
        if let limits {
            service.marginLimits = .success(limits)
        }
        let store = PerpsAccountStore(service: MarginChangeAccountReadingSpy(), wallet: .marginChangeTest())
        store.resolveIfNeeded()
        await waitUntil {
            if case .active = store.currentWalletState() { return true }
            return false
        }
        let viewModel = PerpsMarginChangeViewModel(
            direction: direction,
            summary: PerpsPositionSummary(
                positionId: "lighter:1",
                marketId: 1,
                symbol: "BTC",
                side: .long,
                baseSize: 0.008,
                notionalUsd: 540,
                marginUsd: 20,
                equityUsd: 20.5,
                leverage: 27,
                roiPercent: 2.5,
                entryPrice: 66000,
                liquidationPrice: 64141.75,
                unrealizedPnlUsd: 0.5,
                realizedPnlUsd: 0,
                fundingPaidUsd: nil
            ),
            displayPrice: 66141.70,
            accountStore: store,
            marketsStore: marketsStore,
            tradingService: service,
            format: PerpsFormatting.live
        )
        viewModel.onAppear()
        await waitUntil { viewModel.availableBalance != nil && (limits == nil || viewModel.limits != nil) }
        return (viewModel, service)
    }

    func test_livePriceTick_movesTheHeader() async {
        let client = FakeMarkPricesClient()
        let (viewModel, _) = await makeViewModel(
            direction: .add,
            marketsStore: .makeForTests(tickers: [1: "BTC/USD"], client: client)
        )
        XCTAssertEqual(viewModel.priceText, PerpsFormatting.live.usd(66141.70))

        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67000")])
        await waitUntil { viewModel.priceText == PerpsFormatting.live.usd(67000) }

        XCTAssertEqual(viewModel.priceText, PerpsFormatting.live.usd(67000))
    }

    func test_formShape_noSizeSubtitle_depositOnAddOnly() async {
        let (add, _) = await makeViewModel(direction: .add)
        XCTAssertNil(add.sizeText)
        XCTAssertNotNil(add.balanceRow?.onDeposit)
        XCTAssertNil(add.orderTypeSwitchText)

        let (reduce, _) = await makeViewModel(direction: .reduce)
        XCTAssertNotNil(reduce.balanceRow)
        XCTAssertNil(reduce.balanceRow?.onDeposit)
    }

    func test_belowTheMinimum_disablesReviewWithTheMinimum_bothWays() async {
        for direction in [PerpsMarginChangeDirection.add, .reduce] {
            let (viewModel, _) = await makeViewModel(direction: direction, limits: Self.limits)

            viewModel.setAmount("0.5")

            XCTAssertFalse(viewModel.isReviewEnabled)
            XCTAssertEqual(
                viewModel.balanceRow?.errorText,
                TKLocales.Perps.AdjustMargin.minAmount(PerpsFormatting.live.usd(1))
            )
        }
    }

    func test_reduce_showsTheLimit_fillsItOnMax_andRefusesMore() async {
        let (viewModel, _) = await makeViewModel(direction: .reduce, limits: Self.limits)
        XCTAssertEqual(viewModel.balanceRow?.balanceText, PerpsFormatting.live.usd(2.97))

        viewModel.balanceRow?.onMax()
        XCTAssertEqual(viewModel.amountText, "2.97")
        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertNil(viewModel.balanceRow?.errorText)

        viewModel.setAmount("2.98")
        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertEqual(
            viewModel.balanceRow?.errorText,
            TKLocales.Perps.AdjustMargin.maxReduce(PerpsFormatting.live.usd(2.97))
        )
    }

    func test_liquidationRow_showsOldOnly_untilTheReviewAnswers() async {
        let (viewModel, service) = await makeViewModel(direction: .add)
        let row = { viewModel.optionRows.first { $0.id == "liquidation" } }
        XCTAssertNil(row()?.action)
        XCTAssertEqual(row()?.value, PerpsFormatting.live.usd(64141.75))

        // A review that names no price keeps the plain old value.
        viewModel.setAmount("20")
        XCTAssertEqual(row()?.value, PerpsFormatting.live.usd(64141.75))

        service.reviewer.marginReview = Self.marginReview(new: 63639.99)
        viewModel.setAmount("20")
        await waitUntil { row()?.value != PerpsFormatting.live.usd(64141.75) }

        XCTAssertEqual(row()?.value, "\(PerpsFormatting.live.usd(64141.75)) → \(PerpsFormatting.live.usd(63639.99))")
    }

    func test_reduceAtOrAboveMargin_disablesReviewWithWarning() async {
        let (viewModel, _) = await makeViewModel(direction: .reduce)
        viewModel.setAmount("10")
        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertNil(viewModel.warningText)

        viewModel.setAmount("20")
        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.EditPosition.reduceExceedsMargin(PerpsFormatting.live.usd(20)))
    }

    func test_staleMarketRead_isReplacedOnTheNextChange() async {
        let (viewModel, service) = await makeViewModel(direction: .add)
        service.reviewer.marginReview = Self.marginReview(new: 63639.99)

        viewModel.setAmount("20")
        await waitUntil { service.reviewerLoads == 1 }
        let afterFirstRead = service.reviewerLoads

        // A read within its lifetime is reused: typing does not ask again.
        viewModel.setAmount("21")
        XCTAssertEqual(service.reviewerLoads, afterFirstRead)

        service.reviewer.isStale = true
        viewModel.setAmount("22")

        await waitUntil { service.reviewerLoads > afterFirstRead }
        XCTAssertGreaterThan(service.reviewerLoads, afterFirstRead)
    }

    func test_reduceIntoImmediateRisk_disablesReviewWithWarning() async {
        let (viewModel, service) = await makeViewModel(direction: .reduce)
        service.reviewer.marginReview = Self.marginReview(new: 66100, isImmediateRisk: true)

        viewModel.setAmount("15")
        await waitUntil { viewModel.warningText != nil }

        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.AdjustMargin.reduceRisk)
    }

    func test_review_emitsNormalizedIntent() async {
        let (viewModel, _) = await makeViewModel(direction: .add)
        viewModel.setAmount("20,5")

        var intents: [PerpsMarginChangeIntent] = []
        viewModel.onReview = { intents.append($0) }
        viewModel.review()

        XCTAssertEqual(intents.count, 1)
        XCTAssertEqual(intents.last?.direction, .add)
        XCTAssertEqual(intents.last?.marketId, 1)
        XCTAssertEqual(intents.last?.amountUsd, "20.5")
    }

    func test_reviewFailure_unlocksTheAmountWithTheWarning() async {
        let (viewModel, _) = await makeViewModel(direction: .reduce)
        viewModel.setAmount("5")
        viewModel.review()
        XCTAssertFalse(viewModel.amountFocusState.isActive)

        viewModel.reviewFailed(warning: TKLocales.Perps.AdjustMargin.reduceRisk)

        XCTAssertTrue(viewModel.amountFocusState.isActive)
        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.AdjustMargin.reduceRisk)

        viewModel.review()
        viewModel.reviewFailed(warning: nil)

        XCTAssertTrue(viewModel.amountFocusState.isActive)
        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.AdjustMargin.reduceRisk)
    }

    private static func marginReview(new: Double, isImmediateRisk: Bool = false) -> PerpsMarginChangeReview {
        PerpsMarginChangeReview(
            symbol: "BTC",
            direction: .add,
            side: .long,
            leverage: 10,
            amountUsd: 20,
            allocatedMargin: PerpsValueChange(old: 20, new: 40),
            liquidationPrice: PerpsValueChange(old: 64141.75, new: new),
            liquidationUnavailableReason: nil,
            isImmediateRisk: isImmediateRisk
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        intervalNanoseconds: UInt64 = 5_000_000,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
    }
}

private extension Wallet {
    static func marginChangeTest() -> Wallet {
        let raw = Data("perps-margin-change-test".utf8)
        let padded = raw + Data(repeating: 0, count: max(0, 32 - raw.count))
        let publicKey = TonSwift.PublicKey(data: Data(padded.prefix(32)))
        return Wallet(
            id: "perps-margin-change-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Perps Margin Change Test", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class MarginChangeAccountReadingSpy: PerpsAccountReading, @unchecked Sendable {
    func status(wallet: Wallet) async -> PerpsAccountStatus {
        .account(accountIndex: 1)
    }

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot? {
        PerpsAccountSnapshot(availableBalance: "712.56")
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

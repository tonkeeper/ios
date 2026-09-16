@testable import App
import ChainKit
@testable import KeeperCore
import TKLocalize
import TonSwift
import XCTest

@MainActor
final class PerpsMarginChangeViewModelTests: XCTestCase {
    /// BTC long: 0.008 @ $66 000, margin $20, liq $64 141.75.
    private func makeViewModel(
        direction: PerpsMarginChangeDirection,
        service: FakePerpsTradingService = FakePerpsTradingService()
    ) async -> (viewModel: PerpsMarginChangeViewModel, service: FakePerpsTradingService) {
        let store = PerpsAccountStore(service: MarginChangeAccountReadingSpy(), wallet: .marginChangeTest())
        store.resolveIfNeeded()
        await waitUntil {
            if case .active = store.currentWalletState() { return true }
            return false
        }
        let viewModel = PerpsMarginChangeViewModel(
            direction: direction,
            summary: PerpsPositionSummary(
                marketId: 1,
                symbol: "BTC",
                side: .long,
                baseSize: 0.008,
                notionalUsd: 540,
                marginUsd: 20,
                entryPrice: 66000,
                liquidationPrice: 64141.75,
                unrealizedPnlUsd: 0.5,
                realizedPnlUsd: 0,
                fundingPaidUsd: nil
            ),
            displayPrice: 66141.70,
            accountStore: store,
            tradingService: service
        )
        viewModel.onAppear()
        await waitUntil { viewModel.maintenanceFraction != nil }
        return (viewModel, service)
    }

    func test_formShape_noSizeSubtitle_balanceRowOnAddOnly() async {
        let (add, _) = await makeViewModel(direction: .add)
        XCTAssertNil(add.sizeText)
        XCTAssertNotNil(add.balanceRow)
        XCTAssertNil(add.orderTypeSwitchText)

        let (reduce, _) = await makeViewModel(direction: .reduce)
        XCTAssertNil(reduce.balanceRow)
    }

    func test_liquidationRow_showsOldOnly_untilProjectionAvailable() async {
        let (viewModel, service) = await makeViewModel(direction: .add)
        let row = { viewModel.optionRows.first { $0.id == "liquidation" } }
        XCTAssertNil(row()?.action)
        XCTAssertEqual(row()?.value, PerpsFormatting.usd(64141.75))

        // Preview without a price (unavailable) keeps the plain old value.
        viewModel.setAmount("20")
        XCTAssertEqual(row()?.value, PerpsFormatting.usd(64141.75))

        service.liquidationPreview = PerpsLiquidationPreview(price: 63639.99, isImmediateRisk: false, unavailableReason: nil)
        viewModel.setAmount("20")
        XCTAssertEqual(row()?.value, "\(PerpsFormatting.usd(64141.75)) → \(PerpsFormatting.usd(63639.99))")
    }

    func test_projectionCollateral_isMarginPlusOrMinusAmount() async {
        let (add, addService) = await makeViewModel(direction: .add)
        addService.liquidationPreview = PerpsLiquidationPreview(price: 63639.99, isImmediateRisk: false, unavailableReason: nil)
        add.setAmount("20")
        _ = add.optionRows
        XCTAssertEqual(addService.positionLiquidationPreviews.last, 40)

        let (reduce, reduceService) = await makeViewModel(direction: .reduce)
        reduceService.liquidationPreview = PerpsLiquidationPreview(price: 64700, isImmediateRisk: false, unavailableReason: nil)
        reduce.setAmount("5")
        _ = reduce.optionRows
        XCTAssertEqual(reduceService.positionLiquidationPreviews.last, 15)
    }

    func test_reduceAtOrAboveMargin_disablesReviewWithWarning() async {
        let (viewModel, _) = await makeViewModel(direction: .reduce)
        viewModel.setAmount("10")
        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertNil(viewModel.warningText)

        viewModel.setAmount("20")
        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.EditPosition.reduceExceedsMargin(PerpsFormatting.usd(20)))
    }

    func test_reduceIntoImmediateRisk_disablesReviewWithWarning() async {
        let (viewModel, service) = await makeViewModel(direction: .reduce)
        service.liquidationPreview = PerpsLiquidationPreview(price: 66100, isImmediateRisk: true, unavailableReason: nil)
        viewModel.setAmount("15")
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
    func status(wallet: Wallet) async -> LighterPerpsStatus {
        .active(accountIndex: 1, apiKeyIndex: 0)
    }

    func portfolio(wallet: Wallet, accountIndex: Int64) async throws -> PerpsPortfolio? {
        PerpsPortfolio(
            accountIndex: 1,
            collateral: "0",
            availableBalance: "712.56",
            totalAssetValue: "712.56",
            positions: []
        )
    }

    func activeTriggerOrders(wallet: Wallet, accountIndex: Int64, marketId: Int64) async throws -> [PerpsTriggerOrderSummary] {
        []
    }

    func recentActivity(wallet: Wallet, accountIndex: Int64, marketId: Int64, limit: Int) async throws -> [PerpsActivityItem] {
        []
    }

    func watchPositions(
        wallet: Wallet,
        accountIndex: Int64,
        onUpdate: @escaping @Sendable ([PerpsPositionSummary]) -> Void,
        onReconnecting: @escaping @Sendable () -> Void
    ) -> PerpsPositionsWatch {
        PerpsPositionsWatch {}
    }
}

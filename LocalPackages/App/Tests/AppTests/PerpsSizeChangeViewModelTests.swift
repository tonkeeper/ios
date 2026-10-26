@testable import App
import ChainKit
@testable import KeeperCore
@testable import Perps
import PerpsModels
import TKLocalize
import TonSwift
import XCTest

@MainActor
final class PerpsSizeChangeViewModelTests: XCTestCase {
    /// BTC long: 0.008 @ $66 000, margin $20, notional $540 → 27x.
    private func makeViewModel(
        direction: PerpsSizeChangeDirection,
        triggerOrders: [PerpsTriggerOrderSummary] = [],
        leverage: Double? = 27,
        marketsStore: PerpsMarketsStore = .makeForTests()
    ) async -> PerpsSizeChangeViewModel {
        let reader = SizeChangeAccountReadingSpy()
        reader.triggerOrders = triggerOrders
        let store = PerpsAccountStore(service: reader, wallet: .sizeChangeTest())
        // Settle the store before building the VM: init reads the resting legs
        // synchronously, so the tests don't ride the observer hop.
        store.resolveIfNeeded()
        await waitUntil {
            if case .active = store.currentWalletState() { return true }
            return false
        }
        store.loadMarketExtras(marketId: 1)
        await waitUntil { store.marketExtras(marketId: 1) != nil }
        let session = PerpsSizeChangeSession(
            marketId: 1,
            direction: direction,
            priceDecimals: 2,
            restingTriggerOrders: triggerOrders
        )
        let viewModel = PerpsSizeChangeViewModel(
            session: session,
            summary: PerpsPositionSummary(
                positionId: "lighter:1",
                marketId: 1,
                symbol: "BTC",
                side: .long,
                baseSize: 0.008,
                notionalUsd: 540,
                marginUsd: 20,
                equityUsd: 20.5,
                leverage: leverage,
                roiPercent: 2.5,
                entryPrice: 66000,
                liquidationPrice: 64141.75,
                unrealizedPnlUsd: 0.5,
                realizedPnlUsd: 0,
                fundingPaidUsd: nil
            ),
            displayPrice: 66141.70,
            sizeDecimals: 5,
            accountStore: store,
            marketsStore: marketsStore,
            format: PerpsFormatting.live
        )
        XCTAssertEqual(viewModel.restingTriggerOrders.count, triggerOrders.count, "fixture: store must settle before the VM is built")
        return viewModel
    }

    func test_sizeText_showsOldOnlyWhenEmpty_andOldToNewScaledByLeverage() async {
        let viewModel = await makeViewModel(direction: .add)
        XCTAssertEqual(viewModel.sizeText, PerpsFormatting.live.usd(540))

        viewModel.setAmount("20")
        XCTAssertEqual(viewModel.sizeText, "\(PerpsFormatting.live.usd(540)) → \(PerpsFormatting.live.usd(1080))")
    }

    func test_reduceSizeText_shrinksScaledByLeverage() async {
        let viewModel = await makeViewModel(direction: .reduce)
        viewModel.setAmount("10")
        XCTAssertEqual(viewModel.sizeText, "\(PerpsFormatting.live.usd(540)) → \(PerpsFormatting.live.usd(270))")
    }

    func test_reduceAtOrAboveMargin_disablesReviewWithWarning() async {
        let viewModel = await makeViewModel(direction: .reduce)
        viewModel.setAmount("10")
        XCTAssertTrue(viewModel.isReviewEnabled)
        XCTAssertNil(viewModel.warningText)

        viewModel.setAmount("20")
        XCTAssertFalse(viewModel.isReviewEnabled)
        XCTAssertNotNil(viewModel.warningText)
    }

    func test_balanceRowAndOrderTypeSwitch_addOnlyFormShape() async {
        let add = await makeViewModel(direction: .add)
        XCTAssertNotNil(add.balanceRow)
        XCTAssertNil(add.orderTypeSwitchText)

        let reduce = await makeViewModel(direction: .reduce)
        XCTAssertNil(reduce.balanceRow)
    }

    func test_optionRows_leverageReadOnly_autoCloseAlwaysEditable() async {
        let bare = await makeViewModel(direction: .add)
        XCTAssertEqual(bare.optionRows.map(\.id), ["leverage", "autoClose"])
        XCTAssertNil(bare.optionRows.first { $0.id == "leverage" }?.action)
        let bareAutoClose = bare.optionRows.first { $0.id == "autoClose" }
        XCTAssertNotNil(bareAutoClose?.action)
        XCTAssertEqual(bareAutoClose?.value, TKLocales.Perps.OpenPosition.set)

        let withLegs = await makeViewModel(direction: .add, triggerOrders: [
            PerpsTriggerOrderSummary(orderIndex: 1, kind: .takeProfit, side: .short, triggerPrice: 68141, baseAmount: 0.008),
            PerpsTriggerOrderSummary(orderIndex: 2, kind: .stopLoss, side: .short, triggerPrice: 64720, baseAmount: 0.008),
        ])
        let value = withLegs.optionRows.first { $0.id == "autoClose" }?.value
        XCTAssertEqual(value, "\(PerpsFormatting.live.usd(68141)) TP · \(PerpsFormatting.live.usd(64720)) SL")
    }

    func test_underivableLeverage_keepsTheProjectionAndDropsTheRow() async {
        let viewModel = await makeViewModel(direction: .add, leverage: nil)
        XCTAssertEqual(viewModel.optionRows.map(\.id), ["autoClose"])

        viewModel.setAmount("20")
        XCTAssertEqual(viewModel.sizeText, "\(PerpsFormatting.live.usd(540)) → \(PerpsFormatting.live.usd(1080))")
    }

    func test_autoCloseSheet_carriesTheSizeTheTriggersWillClose() async throws {
        let add = await makeViewModel(direction: .add)
        var contexts = [PerpsAutoCloseSheetContext]()
        add.onOpenAutoClose = { contexts.append($0) }

        add.openAutoClose()
        XCTAssertEqual(try XCTUnwrap(contexts.last?.baseSize), 0.008, accuracy: 1e-12)

        add.setAmount("30")
        add.openAutoClose()
        XCTAssertEqual(try XCTUnwrap(contexts.last?.baseSize), 0.02024, accuracy: 1e-12)

        let reduce = await makeViewModel(direction: .reduce)
        reduce.onOpenAutoClose = { contexts.append($0) }
        reduce.setAmount("5")
        reduce.openAutoClose()
        XCTAssertEqual(try XCTUnwrap(contexts.last?.baseSize), 0.006, accuracy: 1e-12)
    }

    func test_reduceProjection_usesAllocatedMarginAndSizeStep_evenAfterTheMarkMoves() async throws {
        let client = FakeMarkPricesClient()
        let viewModel = await makeViewModel(
            direction: .reduce,
            marketsStore: .makeForTests(tickers: [1: "BTC/USD"], client: client)
        )
        var context: PerpsAutoCloseSheetContext?
        viewModel.onOpenAutoClose = { context = $0 }
        viewModel.onAppear()
        viewModel.setAmount("5.01")
        viewModel.openAutoClose()
        XCTAssertEqual(try XCTUnwrap(context?.baseSize), 0.006, accuracy: 1e-12)

        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "80000")])
        await waitUntil { viewModel.livePrice == 80000 }
        viewModel.openAutoClose()
        XCTAssertEqual(try XCTUnwrap(context?.baseSize), 0.006, accuracy: 1e-12)
        XCTAssertEqual(context?.entryPrice, 66000)
        viewModel.toggleSizeMode()
        XCTAssertEqual(
            viewModel.sizeText,
            "\(PerpsFormatting.live.token(0.008, symbol: "BTC", decimals: 5)) → \(PerpsFormatting.live.token(0.006, symbol: "BTC", decimals: 5))"
        )
        viewModel.onDisappear()
    }

    func test_review_carriesAutoCloseOnlyWhenEdited() async {
        let resting = [
            PerpsTriggerOrderSummary(orderIndex: 1, kind: .takeProfit, side: .short, triggerPrice: 68141, baseAmount: 0.008),
        ]
        let viewModel = await makeViewModel(direction: .reduce, triggerOrders: resting)
        viewModel.setAmount("10")

        var reviewCount = 0
        viewModel.onReview = { reviewCount += 1 }

        viewModel.review()
        XCTAssertEqual(reviewCount, 1)
        XCTAssertEqual(viewModel.intent.autoCloseUpdate, .unchanged)

        let edited = PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 70000),
            stopLoss: nil
        )
        viewModel.applyAutoClose(edited)
        viewModel.review()
        XCTAssertEqual(reviewCount, 2)
        XCTAssertEqual(viewModel.intent.autoCloseUpdate, .replace(edited))

        viewModel.applyAutoClose(PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 68141),
            stopLoss: nil
        ))
        viewModel.review()
        XCTAssertEqual(reviewCount, 3)
        XCTAssertEqual(
            viewModel.intent.autoCloseUpdate,
            .unchanged,
            "edit landing back on the resting legs must not resubmit them"
        )
    }

    func test_applyAutoClose_rejectsInvalidDirectValue() async {
        let viewModel = await makeViewModel(direction: .reduce)
        viewModel.applyAutoClose(PerpsAutoClose(
            takeProfit: PerpsAutoCloseTrigger(triggerPrice: 60000),
            stopLoss: nil
        ))

        XCTAssertEqual(viewModel.intent.autoCloseUpdate, .unchanged)
        XCTAssertEqual(
            viewModel.optionRows.first { $0.id == "autoClose" }?.value,
            TKLocales.Perps.OpenPosition.set
        )
    }

    func test_livePriceTick_movesTheHeaderAndTheAutoCloseReference() async {
        let client = FakeMarkPricesClient()
        let viewModel = await makeViewModel(
            direction: .add,
            marketsStore: .makeForTests(tickers: [1: "BTC/USD"], client: client)
        )
        XCTAssertEqual(viewModel.priceText, PerpsFormatting.live.usd(66141.70))

        viewModel.onAppear()
        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67000")])
        await waitUntil { viewModel.priceText == PerpsFormatting.live.usd(67000) }

        XCTAssertEqual(viewModel.priceText, PerpsFormatting.live.usd(67000))
        var sheet: PerpsAutoCloseSheetContext?
        viewModel.onOpenAutoClose = { sheet = $0 }
        viewModel.openAutoClose()
        XCTAssertEqual(sheet?.referencePrice, 67000)
        XCTAssertEqual(sheet?.livePriceMarketId, 1)
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
    static func sizeChangeTest() -> Wallet {
        let raw = Data("perps-size-change-test".utf8)
        let padded = raw + Data(repeating: 0, count: max(0, 32 - raw.count))
        let publicKey = TonSwift.PublicKey(data: Data(padded.prefix(32)))
        return Wallet(
            id: "perps-size-change-test",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "Perps Size Change Test", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class SizeChangeAccountReadingSpy: PerpsAccountReading, @unchecked Sendable {
    var triggerOrders: [PerpsTriggerOrderSummary] = []

    func status(wallet: Wallet) async -> PerpsAccountStatus {
        .account(accountIndex: 1)
    }

    func portfolio(wallet: Wallet) async throws -> PerpsAccountSnapshot? {
        PerpsAccountSnapshot(availableBalance: "712.56")
    }

    func tradingSnapshot(wallet: Wallet, marketId: Int64, positionId _: String?) async throws -> PerpsTradingSnapshot {
        PerpsTradingSnapshot(flags: .testAllEnabled, orders: PerpsActiveOrders(limitOrders: [], triggerOrders: triggerOrders))
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

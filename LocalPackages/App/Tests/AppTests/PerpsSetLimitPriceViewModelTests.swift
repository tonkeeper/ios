@testable import App
import ChainKit
@testable import KeeperCore
@testable import Perps
import PerpsModels
import TKLocalize
import TKTestSupport
import XCTest

@MainActor
final class PerpsSetLimitPriceViewModelTests: XCTestCase {
    private func makeViewModel(
        side: PerpsTradeSide = .long,
        referencePrice: Double = 66000,
        initialLimitPrice: Double? = nil,
        autoClose: PerpsAutoClose? = nil,
        passedAutoClose: PerpsSetLimitPriceContext.PassedAutoClose = .blocks
    ) -> PerpsSetLimitPriceViewModel {
        let context = PerpsSetLimitPriceContext(
            marketId: 1,
            side: side,
            priceDecimals: 2,
            referencePrice: referencePrice,
            initialLimitPrice: initialLimitPrice,
            autoClose: autoClose,
            passedAutoClose: passedAutoClose
        )
        // Idle prices store: no live price, so MID falls back to the seeded reference price.
        return PerpsSetLimitPriceViewModel(context: context, marketsStore: PerpsMarketsStore.makeForTests(), format: PerpsFormatting.live)
    }

    func test_priceMode_reportsTypedPrice_andEmitsOnSet() {
        let viewModel = makeViewModel()
        XCTAssertFalse(viewModel.isSetEnabled) // empty → disabled
        viewModel.setAmount("65000")
        XCTAssertEqual(viewModel.limitPrice, 65000)
        XCTAssertTrue(viewModel.isSetEnabled)
        XCTAssertNil(viewModel.warningText)

        var reported: Double?
        viewModel.onSet = { reported = $0 }
        viewModel.setLimit()
        XCTAssertEqual(reported, 65000)
    }

    func test_priceMode_longAboveReference_isInvalid() {
        let viewModel = makeViewModel(side: .long, referencePrice: 66000)
        viewModel.setAmount("67000")
        XCTAssertFalse(viewModel.isSetEnabled)
        XCTAssertEqual(viewModel.warningText, "The Limit price must be at or below the current price.")
    }

    func test_priceMode_shortBelowReference_isInvalid() {
        let viewModel = makeViewModel(side: .short, referencePrice: 66000)
        viewModel.setAmount("65000")
        XCTAssertFalse(viewModel.isSetEnabled)
        XCTAssertEqual(viewModel.warningText, "The Limit price must be at or above the current price.")
    }

    func test_percentMode_long_offsetsBelowReference() {
        let viewModel = makeViewModel(side: .long, referencePrice: 66000)
        viewModel.toggleInputMode() // → percent
        viewModel.setAmount("-2")
        // Long sits below the mark: 66000 × (1 − 2%) = 64680.
        XCTAssertEqual(viewModel.limitPrice ?? 0, 64680, accuracy: 1e-6)
    }

    func test_percentMode_short_offsetsAboveReference() {
        let viewModel = makeViewModel(side: .short, referencePrice: 66000)
        viewModel.toggleInputMode()
        viewModel.setAmount("2")
        // Short sits above the mark: 66000 × (1 + 2%) = 67320.
        XCTAssertEqual(viewModel.limitPrice ?? 0, 67320, accuracy: 1e-6)
    }

    func test_quickFill_long_p5_setsActiveAndPrice() {
        let viewModel = makeViewModel(side: .long, referencePrice: 66000)
        viewModel.applyQuickFill(.p5)
        XCTAssertEqual(viewModel.quickFills.first(where: \.isActive)?.fill, .p5)
        // 66000 × 0.95 = 62700.
        XCTAssertEqual(viewModel.limitPrice ?? 0, 62700, accuracy: 1e-6)
    }

    func test_toggleToPercent_preservesSignedOffset() {
        let viewModel = makeViewModel(side: .long, referencePrice: 66000)
        viewModel.setAmount("67320")

        viewModel.toggleInputMode()

        XCTAssertEqual(viewModel.amountText, "+2")
        XCTAssertEqual(viewModel.limitPrice ?? 0, 67320, accuracy: 1e-6)
        XCTAssertEqual(viewModel.warningText, "The Limit price must be at or below the current price.")
    }

    func test_newLong_pastStopLoss_isAnErrorThatBlocksSet() {
        let viewModel = makeViewModel(autoClose: legs(takeProfit: 70000, stopLoss: 61800))

        viewModel.setAmount("61000")

        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.SetLimitPrice.belowStopLoss(price(61800)))
        XCTAssertTrue(viewModel.isWarningBlocking)
        XCTAssertFalse(viewModel.isSetEnabled)
    }

    func test_newShort_pastTakeProfit_isAnErrorThatBlocksSet() {
        let viewModel = makeViewModel(side: .short, referencePrice: 60000, autoClose: legs(takeProfit: 62000, stopLoss: 70000))

        viewModel.setAmount("62000")

        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.SetLimitPrice.belowTakeProfit(price(62000)))
        XCTAssertFalse(viewModel.isSetEnabled)
    }

    func test_newLong_betweenStopLossAndTakeProfit_isAccepted() {
        let viewModel = makeViewModel(autoClose: legs(takeProfit: 70000, stopLoss: 61800))

        viewModel.setAmount("62000")

        XCTAssertNil(viewModel.warningText)
        XCTAssertTrue(viewModel.isSetEnabled)
    }

    func test_editedLong_pastStopLoss_warnsThatItGoesAndKeepsSet() {
        let viewModel = makeViewModel(autoClose: legs(takeProfit: 70000, stopLoss: 61800), passedAutoClose: .isRemoved)

        viewModel.setAmount("61000")

        XCTAssertEqual(
            viewModel.warningText,
            "\(TKLocales.Perps.SetLimitPrice.belowStopLoss(price(61800))). \(TKLocales.Perps.SetLimitPrice.stopLossRemoved)"
        )
        XCTAssertFalse(viewModel.isWarningBlocking)
        XCTAssertTrue(viewModel.isSetEnabled)
    }

    func test_editedShort_pastStopLoss_warnsThatItGoes() {
        let viewModel = makeViewModel(side: .short, autoClose: legs(takeProfit: 62000, stopLoss: 67000), passedAutoClose: .isRemoved)

        viewModel.setAmount("67500")

        XCTAssertEqual(
            viewModel.warningText,
            "\(TKLocales.Perps.SetLimitPrice.aboveStopLoss(price(67000))). \(TKLocales.Perps.SetLimitPrice.stopLossRemoved)"
        )
        XCTAssertTrue(viewModel.isSetEnabled)
    }

    func test_currentPriceErrorWinsOverAutoCloseWarning() {
        let viewModel = makeViewModel(autoClose: legs(takeProfit: 67000, stopLoss: nil), passedAutoClose: .isRemoved)

        viewModel.setAmount("67500")

        XCTAssertEqual(viewModel.warningText, TKLocales.Perps.SetLimitPrice.warningAtOrBelowCurrentPrice)
        XCTAssertTrue(viewModel.isWarningBlocking)
        XCTAssertFalse(viewModel.isSetEnabled)
    }

    func test_quickFill_mid_fallsBackToReference_whenNoBookMid() {
        let viewModel = makeViewModel(referencePrice: 66000)
        viewModel.applyQuickFill(.mid)
        XCTAssertEqual(viewModel.quickFills.first(where: \.isActive)?.fill, .mid)
        XCTAssertEqual(viewModel.limitPrice ?? 0, 66000, accuracy: 1e-6)
        XCTAssertTrue(viewModel.isSetEnabled)
        XCTAssertNil(viewModel.warningText)
    }

    func test_livePriceTick_movesReferencePrice() async {
        let client = FakeMarkPricesClient()
        let store = PerpsMarketsStore.makeForTests(tickers: [1: "BTC/USD"], client: client)
        let context = PerpsSetLimitPriceContext(
            marketId: 1,
            side: .long,
            priceDecimals: 2,
            referencePrice: 66000,
            initialLimitPrice: nil
        )
        let viewModel = PerpsSetLimitPriceViewModel(context: context, marketsStore: store, format: PerpsFormatting.live)

        viewModel.onAppear()
        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67000")])

        await waitUntil(viewModel) { viewModel.referencePriceText == PerpsFormatting.live.price(67000) }
        XCTAssertEqual(viewModel.referencePriceText, PerpsFormatting.live.price(67000))
        viewModel.onDisappear()
    }

    private func legs(takeProfit: Double?, stopLoss: Double?) -> PerpsAutoClose {
        PerpsAutoClose(
            takeProfit: takeProfit.map { PerpsAutoCloseTrigger(triggerPrice: $0) },
            stopLoss: stopLoss.map { PerpsAutoCloseTrigger(triggerPrice: $0) }
        )
    }

    private func price(_ value: Double) -> String {
        PerpsFormatting.live.price(value)
    }
}

@testable import App
import ChainKit
@testable import KeeperCore
import XCTest

@MainActor
final class PerpsSetLimitPriceViewModelTests: XCTestCase {
    private func makeViewModel(
        side: PerpsTradeSide = .long,
        referencePrice: Double = 66000,
        initialLimitPrice: Double? = nil
    ) -> PerpsSetLimitPriceViewModel {
        let context = PerpsSetLimitPriceContext(
            marketId: 1,
            side: side,
            priceDecimals: 2,
            referencePrice: referencePrice,
            initialLimitPrice: initialLimitPrice
        )
        // Idle prices store: no live price, so MID falls back to the seeded reference price.
        return PerpsSetLimitPriceViewModel(context: context, marketsStore: .makeForTests())
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
        XCTAssertEqual(viewModel.activeQuickFill, .p5)
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

    func test_quickFill_mid_fallsBackToReference_whenNoBookMid() {
        let viewModel = makeViewModel(referencePrice: 66000)
        viewModel.applyQuickFill(.mid)
        XCTAssertEqual(viewModel.activeQuickFill, .mid)
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
        let viewModel = PerpsSetLimitPriceViewModel(context: context, marketsStore: store)

        viewModel.onAppear()
        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67000")])

        let deadline = Date().addingTimeInterval(2)
        while viewModel.referencePriceText != PerpsFormatting.usd(67000), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(viewModel.referencePriceText, PerpsFormatting.usd(67000))
        viewModel.onDisappear()
    }
}

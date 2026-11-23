@testable import App
@testable import KeeperCore
@testable import Perps
import PerpsModels
import TKLocalize
import TKTestSupport
import XCTest

@MainActor
final class PerpsAutoCloseSheetLivePriceTests: XCTestCase {
    func test_livePriceTick_revalidatesTheTriggersAgainstTheNewPrice() async {
        let client = FakeMarkPricesClient()
        let store = PerpsMarketsStore.makeForTests(tickers: [1: "BTC/USD"], client: client)
        let viewModel = PerpsAutoCloseSheetViewModel(
            context: makeContext(livePriceMarketId: 1),
            format: PerpsFormatting.live,
            marketsStore: store
        )
        viewModel.setTakeProfitPrice("66500")
        XCTAssertNil(viewModel.takeProfitWarningText)

        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67000")])
        await waitUntil(viewModel) { viewModel.referencePrice == 67000 }

        XCTAssertEqual(viewModel.referencePrice, 67000)
        XCTAssertEqual(viewModel.takeProfitWarningText, TKLocales.Perps.OpenPosition.takeProfitMustBeAboveCurrentPrice)
        XCTAssertFalse(viewModel.isApplyEnabled)
    }

    func test_fixedReference_ignoresTheLivePrice() async {
        let client = FakeMarkPricesClient()
        let store = PerpsMarketsStore.makeForTests(tickers: [1: "BTC/USD"], client: client)
        let interest = store.makePriceInterest()
        interest.set(marketIds: [1])
        let viewModel = PerpsAutoCloseSheetViewModel(
            context: makeContext(livePriceMarketId: nil),
            format: PerpsFormatting.live,
            marketsStore: store
        )
        let live = PerpsAutoCloseSheetViewModel(
            context: makeContext(livePriceMarketId: 1),
            format: PerpsFormatting.live,
            marketsStore: store
        )

        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67000")])
        await waitUntil(live) { live.referencePrice == 67000 }

        XCTAssertEqual(viewModel.referencePrice, 66000)
        interest.clear()
    }

    private func makeContext(livePriceMarketId: Int64?) -> PerpsAutoCloseSheetContext {
        PerpsAutoCloseSheetContext(
            marketId: 1,
            side: .long,
            entryPrice: 66000,
            referencePrice: 66000,
            leverage: 10,
            baseSize: 0.015,
            liquidationPrice: nil,
            priceDecimals: 2,
            draft: nil,
            livePriceMarketId: livePriceMarketId
        )
    }
}

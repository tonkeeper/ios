@testable import App
@testable import KeeperCore
@testable import Perps
import PerpsModels
import TKLocalize
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
        await waitUntil { viewModel.referencePrice == 67000 }

        XCTAssertEqual(viewModel.referencePrice, 67000)
        XCTAssertEqual(viewModel.takeProfitWarningText, TKLocales.Perps.OpenPosition.takeProfitMustBeAboveCurrentPrice)
        XCTAssertFalse(viewModel.isApplyEnabled)
    }

    func test_fixedReference_ignoresTheLivePrice() async throws {
        let client = FakeMarkPricesClient()
        let store = PerpsMarketsStore.makeForTests(tickers: [1: "BTC/USD"], client: client)
        let interest = store.makePriceInterest()
        interest.set(marketIds: [1])
        let viewModel = PerpsAutoCloseSheetViewModel(
            context: makeContext(livePriceMarketId: nil),
            format: PerpsFormatting.live,
            marketsStore: store
        )

        await waitForTickers(client, toEqual: ["BTC/USD"])
        await client.emit([("BTC/USD", "67000")])
        try await Task.sleep(nanoseconds: 300_000_000)

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

    private func waitUntil(timeout: TimeInterval = 2, condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

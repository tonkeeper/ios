@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

@MainActor
final class PerpsRootLimitOrdersTests: XCTestCase {
    private let format = PerpsFormatting(amounts: PerpsTestAmountFormatting())

    func testRestingLimitOrdersAreListedWithoutAnyPosition() {
        let account = StubRootAccountStore()
        account.state = .active(PerpsAccount(
            accountIndex: 7,
            availableBalance: "5.91",
            collateral: "6.85",
            openOrders: [
                makeOrder(marketId: 2, symbol: "ETH", orderIndex: 20, side: .short, limitPrice: 3000, remaining: 0.5),
                makeOrder(marketId: 1, symbol: "BTC", orderIndex: 20, side: .long, limitPrice: 81800, remaining: 0.25),
            ]
        ))

        let portfolio = makeViewModel(account: account).accountState.portfolio

        XCTAssertEqual(portfolio?.positions.isEmpty, true)
        XCTAssertEqual(portfolio?.limitOrders.map(\.id), ["1:20", "2:20"])
        let btc = portfolio?.limitOrders.first
        XCTAssertEqual(btc?.marketId, 1)
        XCTAssertEqual(btc?.symbol, "BTC")
        XCTAssertEqual(btc?.isLong, true)
        XCTAssertEqual(btc?.valueText, format.usd(20450))
        XCTAssertEqual(btc?.limitText, TKLocales.Perps.limitOrderSubtitle(format.usd(81800)))
        XCTAssertEqual(portfolio?.limitOrders.last?.isLong, false)
    }

    private func makeOrder(
        marketId: Int64,
        symbol: String,
        orderIndex: Int64,
        side: PerpsTradeSide,
        limitPrice: Double,
        remaining: Double
    ) -> PerpsPortfolioOrder {
        PerpsPortfolioOrder(
            marketId: marketId,
            symbol: symbol,
            order: PerpsLimitOrderSummary(
                orderIndex: orderIndex,
                clientOrderIndex: orderIndex,
                side: side,
                limitPrice: limitPrice,
                remainingBaseAmount: remaining
            )
        )
    }

    private func makeViewModel(account: StubRootAccountStore) -> PerpsViewModel {
        PerpsViewModel(
            marketsStore: StubRootMarketsStore(),
            accountStore: account,
            format: format
        )
    }
}

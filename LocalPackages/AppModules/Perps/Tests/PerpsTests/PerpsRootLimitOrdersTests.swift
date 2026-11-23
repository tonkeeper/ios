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
        XCTAssertEqual(btc?.limitText, TKLocales.Perps.limitOrderSubtitle(format.price(81800)))
        XCTAssertEqual(portfolio?.limitOrders.last?.isLong, false)
    }

    func testALimitOrderNamesTheLegsPlacedWithIt() {
        let account = StubRootAccountStore()
        account.state = .active(PerpsAccount(
            accountIndex: 7,
            availableBalance: "5.91",
            openOrders: [
                makeOrder(marketId: 1, symbol: "BTC", orderIndex: 20, side: .long, limitPrice: 1950, remaining: 1, autoCloseLegs: [
                    PerpsTriggerOrderSummary(orderIndex: 21, kind: .takeProfit, side: .short, triggerPrice: 2000, baseAmount: 0),
                    PerpsTriggerOrderSummary(orderIndex: 22, kind: .stopLoss, side: .short, triggerPrice: 1900, baseAmount: 0),
                ]),
                makeOrder(marketId: 2, symbol: "ETH", orderIndex: 30, side: .short, limitPrice: 3000, remaining: 0.5, autoCloseLegs: [
                    PerpsTriggerOrderSummary(orderIndex: 31, kind: .stopLoss, side: .long, triggerPrice: 3100, baseAmount: 0),
                ]),
                makeOrder(marketId: 3, symbol: "TON", orderIndex: 40, side: .long, limitPrice: 6, remaining: 10),
            ]
        ))

        let orders = makeViewModel(account: account).accountState.portfolio?.limitOrders

        XCTAssertEqual(orders?.map(\.autoCloseText), [
            "\(TKLocales.Perps.OpenPosition.tp) \(format.price(2000)) · \(TKLocales.Perps.OpenPosition.sl) \(format.price(1900))",
            "\(TKLocales.Perps.OpenPosition.sl) \(format.price(3100))",
            nil,
        ])
    }

    func testALimitOrderShowsTheBackendMarginAndLeverage_neverTheMarketMaximum() {
        let account = StubRootAccountStore()
        account.state = .active(PerpsAccount(
            accountIndex: 7,
            availableBalance: "5.91",
            positions: [PerpsPositionSummary(
                positionId: "eth",
                marketId: 2,
                symbol: "ETH",
                side: .long,
                baseSize: 1,
                notionalUsd: 3100,
                marginUsd: 310,
                equityUsd: 310,
                leverage: 10,
                roiPercent: nil,
                entryPrice: 3100,
                liquidationPrice: 2800,
                unrealizedPnlUsd: 0,
                realizedPnlUsd: 0,
                fundingPaidUsd: nil
            )],
            openOrders: [
                makeOrder(
                    marketId: 1,
                    symbol: "ZEC",
                    orderIndex: 20,
                    side: .long,
                    limitPrice: 105.4,
                    remaining: 0.1,
                    marginUsd: 3.51,
                    leverage: 3
                ),
                makeOrder(marketId: 2, symbol: "ETH", orderIndex: 21, side: .short, limitPrice: 3000, remaining: 0.5),
            ]
        ))
        let markets = StubRootMarketsStore(markets: PerpsMarkets(
            sort: .volume,
            items: [PerpsMarketSummary(
                marketId: 2,
                symbol: "ETH",
                name: "Ethereum",
                iconURL: nil,
                maxLeverage: 50,
                price: 3100,
                priceChangePercent: 0,
                volume24h: 0
            )],
            livePrices: [:],
            hasNextPage: false,
            isLoadingNextPage: false
        ))

        let orders = makeViewModel(account: account, markets: markets).accountState.portfolio?.limitOrders

        XCTAssertEqual(orders?.map(\.valueText), [format.usd(3.51), "—"])
        XCTAssertEqual(orders?.map(\.leverageText), [format.leverage(3).uppercased(), nil])
    }

    private func makeOrder(
        marketId: Int64,
        symbol: String,
        orderIndex: Int64,
        side: PerpsTradeSide,
        limitPrice: Double,
        remaining: Double,
        marginUsd: Double? = nil,
        leverage: Double? = nil,
        autoCloseLegs: [PerpsTriggerOrderSummary] = []
    ) -> PerpsPortfolioOrder {
        PerpsPortfolioOrder(
            marketId: marketId,
            symbol: symbol,
            order: PerpsLimitOrderSummary(
                orderIndex: orderIndex,
                clientOrderIndex: orderIndex,
                side: side,
                limitPrice: limitPrice,
                remainingBaseAmount: remaining,
                autoCloseLegs: autoCloseLegs
            ),
            marginUsd: marginUsd,
            leverage: leverage
        )
    }

    private func makeViewModel(account: StubRootAccountStore, markets: StubRootMarketsStore = StubRootMarketsStore()) -> PerpsViewModel {
        PerpsViewModel(
            marketsStore: markets,
            accountStore: account,
            access: { .available },
            reloadAccess: { .available },
            format: format
        )
    }
}

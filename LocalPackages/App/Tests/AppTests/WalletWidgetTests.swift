@testable import App
import BigInt
import KeeperCore
import WidgetKit
import XCTest

final class WalletWidgetTests: XCTestCase {
    func testLinkRoundTripsAndTagsTheFlowItOpens() throws {
        let link = WalletWidgetLink(widget: .balance, family: .systemMedium, action: .send, walletId: "wallet/1")
        let url = try XCTUnwrap(link.url)

        XCTAssertEqual(WalletWidgetLink(url: url), link)
        XCTAssertEqual(UtmParameters(link: url.absoluteString).source, "tonkeeper")
        XCTAssertEqual(UtmParameters(link: url.absoluteString).medium, "widget")
        XCTAssertEqual(UtmParameters(link: url.absoluteString).content, "balance_system_medium")
    }

    func testActionsWidgetLinksRoundTripBuyAndStake() throws {
        for action in [WalletWidgetLink.Action.buy, .stake] {
            let link = WalletWidgetLink(widget: .actions, family: .systemSmall, action: action, walletId: nil)
            XCTAssertEqual(try WalletWidgetLink(url: XCTUnwrap(link.url)), link)
        }
        XCTAssertEqual(WalletWidgetLink.Widget(kind: "ActionsWidget"), .actions)
    }

    func testLinkWithoutActionOpensTheAppAndOtherLinksAreNotWidgets() throws {
        let link = try XCTUnwrap(WalletWidgetLink(url: XCTUnwrap(URL(string: "tonkeeper://widget?widget=balance&family=system_small"))))
        XCTAssertEqual(link.action, .open)
        XCTAssertNil(link.walletId)

        XCTAssertNil(URL(string: "tonkeeper://live-activity?widget=balance&family=system_small").flatMap(WalletWidgetLink.init(url:)))
        XCTAssertNil(URL(string: "tonkeeper://widget?widget=unknown&family=system_small").flatMap(WalletWidgetLink.init(url:)))
        XCTAssertNil(URL(string: "tonkeeper://widget?widget=balance").flatMap(WalletWidgetLink.init(url:)))
    }

    func testPriceWidgetLinkCarriesItsAsset() throws {
        let link = WalletWidgetLink(widget: .watchlist, family: .systemLarge, action: .open, walletId: nil, assetId: "ton/mainnet/jetton/0:abc")
        let url = try XCTUnwrap(link.url)

        XCTAssertEqual(WalletWidgetLink(url: url), link)
        XCTAssertEqual(UtmParameters(link: url.absoluteString).content, "watchlist_system_large")
        XCTAssertNil(try XCTUnwrap(WalletWidgetLink(url: XCTUnwrap(URL(string: "tonkeeper://widget?widget=rate&family=system_small")))).assetId)
    }

    func testWatchlistShowsFavoritesThenTheWalletsLargestAssetsThenTon() {
        let btc = PriceWidgetSnapshot.Asset(id: "btc", symbol: "BTC")
        let usdt = PriceWidgetSnapshot.Asset(id: "usdt", symbol: "USDT")

        XCTAssertEqual(PriceWidgetSnapshot(favorites: [btc], walletAssets: [usdt], currency: nil).watchlist, [btc])
        XCTAssertEqual(PriceWidgetSnapshot(favorites: [], walletAssets: [usdt, btc], currency: nil).watchlist, [usdt, btc])
        XCTAssertEqual(PriceWidgetSnapshot.empty.watchlist, [.ton])
    }

    func testPriceWidgetChoicesListEachAssetOnceWithTonAlwaysThere() {
        let btc = PriceWidgetSnapshot.Asset(id: "btc", symbol: "BTC")
        let usdt = PriceWidgetSnapshot.Asset(id: "usdt", symbol: "USDT")

        XCTAssertEqual(PriceWidgetSnapshot(favorites: [btc, .ton], walletAssets: [usdt, btc], currency: nil).choices, [btc, .ton, usdt])
        XCTAssertEqual(PriceWidgetSnapshot.empty.choices, [.ton])
    }

    func testWalletAssetsAreTheListedOnesLargestInFiatFirst() {
        let assets = [
            makeAsset("small", balance: 1, price: 2),
            makeAsset("hidden", balance: 1000, price: 1, isHidden: true),
            makeAsset("scam", balance: 1000, price: 1, verification: .blacklist),
            makeAsset("large", balance: 10, price: 3),
            makeAsset("empty", balance: 0, price: 100),
            makeAsset("unpriced", balance: 1000, price: nil),
        ] + (1 ... 6).map { makeAsset("filler\($0)", balance: 1, price: 1) }

        let ids = WalletWidgetSnapshotPublisher.largestAssets(assets, currency: .USD).map(\.asset.asset.assetId)

        XCTAssertEqual(ids, ["large", "small", "filler1", "filler2", "filler3"])
    }

    func testChangeIsWhatTheTokensGainedAtTheirPrices() throws {
        // Worth 110 after +10% and 50 after −50%: they were 100 and 100.
        let assets = [
            makeAsset("up", balance: 11, price: 10, diff24h: "+10%"),
            makeAsset("down", balance: 5, price: 10, diff24h: "\u{2212}50.00 %"),
            makeAsset("hidden", balance: 1000, price: 1, isHidden: true),
            makeAsset("empty", balance: 0, price: 1),
        ]

        let change = try XCTUnwrap(WalletWidgetSnapshotPublisher.change24h(assets, currency: .USD))

        XCTAssertEqual(NSDecimalNumber(decimal: change).doubleValue, -40, accuracy: 0.0001)
    }

    func testChangeIsUnknownRatherThanPartial() throws {
        let priced = makeAsset("priced", balance: 1, price: 10, diff24h: "+1%")

        XCTAssertNil(WalletWidgetSnapshotPublisher.change24h([priced, makeAsset("noChange", balance: 1, price: 10)], currency: .USD))
        XCTAssertNil(WalletWidgetSnapshotPublisher.change24h([priced, makeAsset("wiped", balance: 1, price: 10, diff24h: "-100%")], currency: .USD))
        // A price only in USD is not mixed into a EUR change.
        XCTAssertNil(try WalletWidgetSnapshotPublisher.change24h([priced], currency: XCTUnwrap(Currency(code: "EUR"))))
        XCTAssertNil(WalletWidgetSnapshotPublisher.change24h([], currency: .USD))
    }

    func testPriceChangeIsTheChartsMoveOrBackedOutOfTheCatalogsPercent() throws {
        let fromChart = try XCTUnwrap(PriceWidgetSnapshot.change(prices: [2, 2.5, 1.5], price: 1.5, percent24h: 10))
        XCTAssertEqual(fromChart.percent, -25)
        XCTAssertEqual(fromChart.amount, -0.5)

        // Up 25% to 1.25 means it was 1: the change is 0.25, not 25% of the current price.
        let fromPercent = try XCTUnwrap(PriceWidgetSnapshot.change(prices: [1.25], price: 1.25, percent24h: 25))
        XCTAssertEqual(fromPercent.amount, 0.25)

        XCTAssertNil(PriceWidgetSnapshot.change(prices: [], price: 1, percent24h: -100))
        XCTAssertNil(PriceWidgetSnapshot.change(prices: [0, 1], price: 1, percent24h: nil))
    }

    func testCompactTotalFitsTheCircularWidget() {
        let locale = Locale(identifier: "en_US")

        XCTAssertEqual(WalletWidgetSnapshotPublisher.compactFiat(8245.6, currency: .USD, locale: locale), "$8.2K")
        XCTAssertEqual(WalletWidgetSnapshotPublisher.compactFiat(1_999_999, currency: .USD, locale: locale), "$1.9M")
        XCTAssertEqual(WalletWidgetSnapshotPublisher.compactFiat(245.67, currency: .USD, locale: locale), "$245.6")
        XCTAssertEqual(WalletWidgetSnapshotPublisher.compactFiat(-8245.6, currency: .USD, locale: locale), "$-8.2K")
    }

    func testWidgetShowsItsWalletThenTheActiveOneThenTheFirst() {
        let first = makeWallet(id: "first")
        let active = makeWallet(id: "active")
        let configured = makeWallet(id: "configured")
        let snapshot = WalletWidgetSnapshot(wallets: [first, active, configured], activeWalletId: "active", hidesAmounts: false, isRampEnabled: false, decimalSeparator: ".")

        XCTAssertEqual(snapshot.wallet(id: "configured"), configured)
        XCTAssertEqual(snapshot.wallet(id: "deleted"), active)
        XCTAssertEqual(snapshot.wallet(id: nil), active)
        XCTAssertEqual(
            WalletWidgetSnapshot(wallets: [first, configured], activeWalletId: nil, hidesAmounts: false, isRampEnabled: false, decimalSeparator: ".").wallet(id: nil),
            first
        )
        XCTAssertNil(WalletWidgetSnapshot.empty.wallet(id: nil))
    }

    func testPlacedWidgetsListOnlyTonkeeperOnesWithEachCopy() {
        let value = PlacedWidgets.analyticsValue(of: [
            (kind: "RateWidget", family: .systemSmall),
            (kind: "BalanceWidget", family: .accessoryInline),
            (kind: "SomeoneElsesWidget", family: .systemSmall),
            (kind: "BalanceWidget", family: .systemMedium),
            (kind: "BalanceWidget", family: .systemMedium),
        ])

        XCTAssertEqual(value, ["rate:system_small", "balance:accessory_inline", "balance:system_medium", "balance:system_medium"])
        XCTAssertEqual(PlacedWidgets.analyticsValue(of: [(kind: String, family: WidgetFamily)]()), [])
    }

    private func makeAsset(
        _ id: String,
        balance: Int,
        price: Double?,
        diff24h: String? = nil,
        isHidden: Bool = false,
        verification: MultichainAssetVerification = .none
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(assetId: id, name: id, symbol: id, decimals: 0, image: "", verification: verification),
            price: MultichainAssetPrice(prices: price.map { ["USD": $0] } ?? [:], diff24h: diff24h.map { ["USD": $0] } ?? [:], diff7d: [:]),
            isHidden: isHidden,
            balance: BigUInt(balance)
        )
    }

    private func makeWallet(id: String) -> WalletWidgetSnapshot.Wallet {
        WalletWidgetSnapshot.Wallet(
            id: id,
            name: id,
            emoji: nil,
            icon: nil,
            total: nil,
            totalCompact: nil,
            change: nil,
            topAssets: [],
            updatedAt: nil,
            actions: []
        )
    }
}

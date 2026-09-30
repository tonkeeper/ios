import Foundation
@testable import KeeperCore
import TKTradingAPI
import XCTest

final class PerpsMarketsRepositoryTests: XCTestCase {
    func testMarketsRequestsPerpetualsPageAndMapsCatalogRows() async throws {
        let api = TradingAPIFake()
        api.catalogPages[nil] = Components.Schemas.AssetsCatalogResponse(
            items: [
                makeItem(
                    assetId: "lighter/mainnet/7",
                    symbol: "ETH",
                    name: "Ethereum",
                    imageURL: "https://cdn.example.com/eth.png",
                    leverage: 40,
                    price: "3421.55",
                    change24h: "-1.84%",
                    volume: "1023874500.00"
                ),
                makeItem(assetId: "ton/mainnet/coin", symbol: "TON", name: "Toncoin", imageURL: "", leverage: nil, price: "3", change24h: "1", volume: "0"),
                makeItem(assetId: "lighter/mainnet/9", symbol: "", name: "Nameless", imageURL: "", leverage: 5, price: "1", change24h: "1", volume: "0"),
            ],
            next_cursor: "c2",
            data_freshness_sec: 5
        )
        let contextProvider = RequestContextStub(currency: .EUR)
        let repository = PerpsMarketsRepository(api: api, requestContextProvider: contextProvider)

        let page = try await repository.markets(query: nil, sort: .openInterest, cursor: nil)

        XCTAssertEqual(page.nextCursor, "c2")
        XCTAssertEqual(page.items.count, 1)
        let market = try XCTUnwrap(page.items.first)
        XCTAssertEqual(market.marketId, 7)
        XCTAssertEqual(market.symbol, "ETH")
        XCTAssertEqual(market.name, "Ethereum")
        XCTAssertEqual(market.iconURL, URL(string: "https://cdn.example.com/eth.png"))
        XCTAssertEqual(market.maxLeverage, 40)
        XCTAssertEqual(market.price, 3421.55, accuracy: 1e-9)
        XCTAssertEqual(market.priceChangePercent, -1.84, accuracy: 1e-9)
        XCTAssertEqual(market.volume24h, 1_023_874_500, accuracy: 1e-6)
        XCTAssertEqual(api.catalogRequests, [
            .init(
                tab: .perpetuals,
                sort: .open_interest_usd,
                order: .desc,
                cursor: nil,
                pageSize: 50,
                showPerps: nil,
                chain: nil
            ),
        ])
        let context = await contextProvider.makeRequestContext()
        XCTAssertEqual(api.catalogContexts.first?.currency, .USD)
        XCTAssertEqual(context.currency, .EUR)
        XCTAssertEqual(api.catalogContexts, [context.withCurrency(.USD)])
    }

    func testCatalogSearchMixesSpotAndPerpRowsAndOmitsShowPerpsWhenChainIsSet() async throws {
        let api = TradingAPIFake()
        api.catalogPages[nil] = Components.Schemas.AssetsCatalogResponse(
            items: [
                makeItem(
                    assetId: "ton/mainnet/coin",
                    symbol: "TON",
                    name: "Toncoin",
                    imageURL: "https://cdn.example.com/ton.png",
                    leverage: nil,
                    price: "3.1",
                    change24h: "1.2",
                    volume: "10"
                ),
                makeItem(
                    assetId: "lighter/mainnet/market/7",
                    symbol: "ETH",
                    name: "Ethereum",
                    imageURL: "https://cdn.example.com/eth.png",
                    leverage: 40,
                    price: "3421.55",
                    change24h: "-1.84%",
                    volume: "1023874500.00",
                    assetType: .perpetuals
                ),
            ],
            next_cursor: "next",
            data_freshness_sec: 1
        )
        let repository = PerpsMarketsRepository(
            api: api,
            requestContextProvider: RequestContextStub(currency: .USD)
        )

        let mixed = try await repository.catalogSearch(
            query: "eth",
            chain: nil,
            showPerps: true,
            sort: .volume,
            cursor: nil,
            pageSize: 30
        )
        XCTAssertEqual(mixed.nextCursor, "next")
        XCTAssertEqual(mixed.rows.count, 2)
        guard case let .spot(spot) = mixed.rows[0] else {
            return XCTFail("expected spot row")
        }
        XCTAssertEqual(spot.id, "ton/mainnet/coin")
        guard case let .perp(market) = mixed.rows[1] else {
            return XCTFail("expected perp row")
        }
        XCTAssertEqual(market.marketId, 7)
        XCTAssertEqual(
            api.catalogRequests.last,
            .init(
                tab: .all,
                sort: .volume_24h,
                order: .desc,
                cursor: nil,
                pageSize: 30,
                showPerps: true,
                chain: nil
            )
        )

        _ = try await repository.catalogSearch(
            query: nil,
            chain: "ton",
            showPerps: true,
            sort: .marketCap,
            cursor: nil,
            pageSize: 30
        )
        XCTAssertEqual(
            api.catalogRequests.last,
            .init(
                tab: .all,
                sort: .market_cap,
                order: .desc,
                cursor: nil,
                pageSize: 30,
                showPerps: nil,
                chain: "ton"
            )
        )
    }

    func testMetadataMapperRejectsUnusableMarkets() {
        XCTAssertNil(PerpsMarketMetadata(perps: makePerpMarket(marketIndex: 1, symbol: "")))
        XCTAssertNil(PerpsMarketMetadata(perps: makePerpMarket(marketIndex: 2, symbol: "ETH", maxLeverage: 0)))
        XCTAssertNil(PerpsMarketMetadata(perps: makePerpMarket(marketIndex: 3, symbol: "ETH", minSizeBase: "0")))
        XCTAssertNotNil(PerpsMarketMetadata(perps: makePerpMarket(marketIndex: 5, symbol: "ETH")))
    }
}

private func makeItem(
    assetId: String,
    symbol: String,
    name: String,
    imageURL: String,
    leverage: Int?,
    price: String,
    change24h: String,
    volume: String,
    assetType: Components.Schemas.AssetType = .asset
) -> Components.Schemas.MarketItem {
    Components.Schemas.MarketItem(
        asset: Components.Schemas.AssetRefSummary(
            asset_type: assetType,
            id: assetId,
            symbol: symbol,
            name: name,
            decimals: 8,
            trust_score: 100,
            image_url: imageURL,
            is_scam: false,
            verification: .whitelist,
            leverage: leverage
        ),
        metrics: Components.Schemas.MarketMetricsSummary(
            volume: volume,
            price: price,
            change_24h_percent: change24h,
            provider: "lighter",
            as_of: Date(timeIntervalSince1970: 0)
        )
    )
}

private func makePerpMarket(
    marketIndex: Int,
    symbol: String,
    quoteAsset: String = "USDC",
    maxLeverage: Int = 40,
    minSizeBase: String = "0.001",
    takerFeePct: String = "0.05"
) -> Components.Schemas.PerpMarket {
    Components.Schemas.PerpMarket(
        market_index: marketIndex,
        symbol: symbol,
        base_asset: symbol,
        quote_asset: quoteAsset,
        status: "active",
        price_decimals: 2,
        size_decimals: 4,
        tick_size: "0.01",
        step_size: "0.0001",
        min_size_base: minSizeBase,
        max_size_base: "",
        min_size_quote: "10",
        max_size_quote: "1000000",
        max_leverage: maxLeverage,
        maker_fee_pct: "0.02",
        taker_fee_pct: takerFeePct,
        initial_margin_fraction: 250,
        maintenance_margin_fraction: 125,
        closeout_margin_fraction: 100,
        funding_rate_hourly: "0.0000125",
        open_interest_usd: "48213900.00",
        volume_24h_usd: "1023874500.00",
        last_price: "3421.55",
        index_price: "3421.10",
        mark_price: "3421.72",
        price_change_24h: "-1.84",
        high_24h: "3502.10",
        low_24h: "3380.00"
    )
}

private struct RequestContextStub: TradingRequestContextProvider {
    var currency: Currency = .USD

    func makeRequestContext() async -> TradingRequestContext {
        TradingRequestContext(
            currency: currency,
            language: "en",
            userAgent: "test",
            storeCountryCode: nil,
            simCountryCode: nil,
            deviceCountryCode: nil,
            timezoneIdentifier: "UTC",
            isVPNActive: nil
        )
    }
}

private final class TradingAPIFake: TradingAPI, @unchecked Sendable {
    struct CatalogRequest: Equatable {
        let tab: Components.Schemas.AssetsTab
        let sort: Components.Schemas.AssetsSort?
        let order: Components.Schemas.AssetsOrder?
        let cursor: String?
        let pageSize: Int?
        let showPerps: Bool?
        let chain: String?
    }

    private let lock = NSLock()
    private var _catalogRequests: [CatalogRequest] = []
    private var _catalogContexts: [TradingRequestContext] = []
    var catalogPages: [String?: Components.Schemas.AssetsCatalogResponse] = [:]

    var catalogRequests: [CatalogRequest] {
        lock.withLock { _catalogRequests }
    }

    var catalogContexts: [TradingRequestContext] {
        lock.withLock { _catalogContexts }
    }

    func getAssetChart(
        requestContext _: TradingRequestContext,
        assetId _: String,
        period _: Period,
        currency _: Currency
    ) async throws(TradingAPIError) -> [Coordinate] {
        throw .unknown(underlying: nil)
    }

    func getShelves(
        requestContext _: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponse {
        throw .unknown(underlying: nil)
    }

    func getShelvesV2(
        requestContext _: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponseV2 {
        throw .unknown(underlying: nil)
    }

    func getAssetsCatalog(
        requestContext _: TradingRequestContext,
        tab _: Components.Schemas.AssetsTab,
        query _: String?,
        cursor _: String?,
        pageSize _: Int?,
        sourceShelf _: String?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        throw .unknown(underlying: nil)
    }

    func getAssetsCatalogV2(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query _: String?,
        sort: Components.Schemas.AssetsSort?,
        order: Components.Schemas.AssetsOrder?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf _: String?,
        showPerps: Bool?,
        chain: String?,
        filter _: Components.Schemas.AssetsFilter?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        let page = lock.withLock { () -> Components.Schemas.AssetsCatalogResponse? in
            _catalogContexts.append(requestContext)
            _catalogRequests.append(
                CatalogRequest(
                    tab: tab,
                    sort: sort,
                    order: order,
                    cursor: cursor,
                    pageSize: pageSize,
                    showPerps: showPerps,
                    chain: chain
                )
            )
            return catalogPages[cursor]
        }
        guard let page else { throw .badStatus(message: "no page for cursor \(cursor ?? "nil")") }
        return page
    }

    func getAssets(
        requestContext _: TradingRequestContext,
        ids _: [String]
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        throw .unknown(underlying: nil)
    }

    func getAssetsDetailsV2(
        requestContext _: TradingRequestContext,
        assetId _: String
    ) async throws(TradingAPIError) -> Components.Schemas.AssetDetailsResponse {
        throw .unknown(underlying: nil)
    }
}

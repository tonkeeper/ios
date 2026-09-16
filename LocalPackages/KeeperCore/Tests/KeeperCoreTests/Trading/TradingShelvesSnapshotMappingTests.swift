@testable import KeeperCore
import TKTradingAPI
import XCTest

final class TradingShelvesSnapshotMappingTests: XCTestCase {
    func test_v1Response_mapsShelfToSingleGroup() {
        let response = Components.Schemas.ShelvesConfigResponse(
            groups: [
                makeShelfGroup(
                    name: "Market",
                    items: [
                        makeShelfConfig(
                            key: .most_traded,
                            title: "Most traded",
                            items: [makeMarketItem(id: "ton/mainnet/coin")]
                        ),
                    ]
                ),
            ],
            generated_at: .now
        )

        let snapshot = TradingShelvesSnapshot(
            response: response,
            currency: .USD
        )

        XCTAssertEqual(snapshot.shelves.count, 1)
        XCTAssertEqual(snapshot.shelves[0].title, "Market")
        XCTAssertEqual(snapshot.shelves[0].groups.map(\.title), ["Market"])
        XCTAssertEqual(snapshot.shelves[0].groups[0].grids.map(\.id), ["most_traded"])
    }

    func test_v2Response_mapsShelfAndChainGroupTitlesAndDropsEmptyGroups() {
        let response = Components.Schemas.ShelvesConfigResponseV2(
            groups: [
                Components.Schemas.MultichainShelfGroup(
                    id: "top-tokens",
                    name: "Top tokens",
                    groups: [
                        makeShelfGroup(
                            name: "TON",
                            items: [
                                makeShelfConfig(
                                    key: .most_traded,
                                    title: "Volume",
                                    items: [makeMarketItem(id: "ton/mainnet/coin")]
                                ),
                            ]
                        ),
                        makeShelfGroup(name: "Empty", items: []),
                        makeShelfGroup(
                            name: "TRON",
                            items: [
                                makeShelfConfig(
                                    key: .top_gainers,
                                    title: "Market Cap",
                                    items: [makeMarketItem(id: "tron/mainnet/usdt")]
                                ),
                            ]
                        ),
                    ]
                ),
                Components.Schemas.MultichainShelfGroup(
                    id: "empty-shelf",
                    name: "Empty shelf",
                    groups: [
                        makeShelfGroup(name: "No assets", items: []),
                    ]
                ),
            ],
            generated_at: .now
        )

        let snapshot = TradingShelvesSnapshot(
            response: response,
            currency: .USD
        )

        XCTAssertEqual(snapshot.shelves.count, 1)
        XCTAssertEqual(snapshot.shelves[0].id, "top-tokens")
        XCTAssertEqual(snapshot.shelves[0].title, "Top tokens")
        XCTAssertEqual(snapshot.shelves[0].groups.map(\.title), ["TON", "TRON"])
        XCTAssertEqual(snapshot.shelves[0].groups[0].grids.map(\.name), ["Volume"])
        XCTAssertEqual(snapshot.shelves[0].groups[1].grids.map(\.name), ["Market Cap"])
    }

    func test_shelfGrid_mapsListKeysToInitialCatalogSort() throws {
        let expectedSorts: [(Components.Schemas.MarketListKey, MultichainAssetSearchSort)] = [
            (.market_cap, .marketCap),
            (.volume, .volume),
            (.top_gainers, .priceDiffDesc),
            (.top_losers, .priceDiffAsc),
            (.most_traded, .marketCap),
        ]

        for (key, expectedSort) in expectedSorts {
            let grid = try XCTUnwrap(
                TradingShelfGrid(
                    config: makeShelfConfig(
                        key: key,
                        title: key.rawValue,
                        items: [makeMarketItem(id: "ton/mainnet/coin")]
                    )
                )
            )

            XCTAssertEqual(grid.initialCatalogSearchSort, expectedSort, key.rawValue)
        }
    }
}

private extension TradingShelvesSnapshotMappingTests {
    func makeShelfGroup(
        name: String,
        items: [Components.Schemas.ShelfConfig]
    ) -> Components.Schemas.ShelfGroup {
        Components.Schemas.ShelfGroup(
            name: name,
            items: items
        )
    }

    func makeShelfConfig(
        key: Components.Schemas.MarketListKey,
        title: String,
        items: [Components.Schemas.MarketItem]
    ) -> Components.Schemas.ShelfConfig {
        Components.Schemas.ShelfConfig(
            key: key,
            title: title,
            _type: .grid,
            source: "api",
            see_all: Components.Schemas.ShelfConfig.see_allPayload(
                enabled: true,
                route: .all
            ),
            items: items
        )
    }

    func makeMarketItem(id: String) -> Components.Schemas.MarketItem {
        Components.Schemas.MarketItem(
            asset: Components.Schemas.AssetRefSummary(
                asset_type: .asset,
                id: id,
                symbol: "TON",
                name: "Toncoin",
                decimals: 9,
                trust_score: 100,
                image_url: "https://example.com/icon.png",
                is_scam: false,
                verification: .whitelist
            ),
            metrics: Components.Schemas.MarketMetricsSummary(
                volume: "0",
                price: "1",
                change_24h_percent: "0",
                provider: "test",
                as_of: .now
            )
        )
    }
}

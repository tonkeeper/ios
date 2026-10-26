import Foundation
@testable import KeeperCore
import TKTradingAPI
import XCTest

final class TradingAssetPerpMarketMappingTests: XCTestCase {
    func test_firstPerpMarketBecomesTheAssetEntryPoint() throws {
        let details = try makeDetails(perpMarkets: """
        [
          {"id":"lighter/mainnet/market/3","market_index":3,"symbol":"GRAM","category":"crypto","max_leverage":10},
          {"id":"lighter/mainnet/market/9","market_index":9,"symbol":"GRAM2","category":"crypto","max_leverage":5}
        ]
        """)

        XCTAssertEqual(details.perpMarket, TradingAssetPerpMarket(marketId: 3, maxLeverage: 10))
    }

    func test_marketIsIdentifiedByItsAssetId_likeTheCatalog() throws {
        let details = try makeDetails(perpMarkets: #"[{"id":"lighter/mainnet/market/3","market_index":4,"symbol":"GRAM","category":"crypto"}]"#)

        XCTAssertEqual(details.perpMarket?.marketId, 3)
    }

    func test_linksTheAppCannotOpenAreSkipped() throws {
        let details = try makeDetails(perpMarkets: """
        [
          {"id":"hyperliquid/mainnet/market/9","market_index":9,"symbol":"GRAM","category":"crypto","max_leverage":40},
          {"id":"lighter/testnet/market/7","market_index":7,"symbol":"GRAM","category":"crypto","max_leverage":20},
          {"id":"lighter/mainnet/market/3","market_index":3,"symbol":"GRAM","category":"crypto","max_leverage":10}
        ]
        """)

        XCTAssertEqual(details.perpMarket, TradingAssetPerpMarket(marketId: 3, maxLeverage: 10))
    }

    func test_onlyUnopenableLinks_meanNoEntryPoint() throws {
        let details = try makeDetails(perpMarkets: #"[{"id":"lighter/testnet/market/7","market_index":7,"symbol":"GRAM","category":"crypto"}]"#)

        XCTAssertNil(details.perpMarket)
    }

    func test_unknownCategoryAndMissingLeverageStillDecode() throws {
        let details = try makeDetails(perpMarkets: #"[{"id":"lighter/mainnet/market/3","market_index":3,"symbol":"GRAM","category":"forex"}]"#)

        XCTAssertEqual(details.perpMarket, TradingAssetPerpMarket(marketId: 3, maxLeverage: nil))
    }

    func test_assetWithoutPerpMarketsHasNoEntryPoint() throws {
        XCTAssertNil(try makeDetails(perpMarkets: nil).perpMarket)
    }
}

private extension TradingAssetPerpMarketMappingTests {
    func makeDetails(perpMarkets: String?) throws -> TradingAssetDetails {
        let perpMarketsField = perpMarkets.map { #", "perp_markets": \#($0)"# } ?? ""
        let json = """
        {
          "asset": {
            "asset_type": "asset",
            "id": "ton/mainnet/coin",
            "symbol": "GRAM",
            "name": "Gram",
            "decimals": 9,
            "trust_score": 100,
            "image_url": "https://example.com/gram.png",
            "is_scam": false,
            "verification": "whitelist"\(perpMarketsField)
          },
          "sections": {
            "about": {"enabled": false},
            "overview": {"enabled": false},
            "trading_activity": {"enabled": false},
            "links": {"enabled": false}
          },
          "data_freshness_sec": 0,
          "info_source": {"displayed_name": "dyor.io", "url": "https://dyor.io/"}
        }
        """
        let response = try JSONDecoder().decode(Components.Schemas.AssetDetailsResponse.self, from: Data(json.utf8))
        return TradingAssetDetails(response: response, currency: .USD)
    }
}

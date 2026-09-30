import Foundation
@testable import KeeperCore
import XCTest

final class PerpsMarketDetailsServiceTests: XCTestCase {
    func testLoad_mapsCatalogDetailsToSnapshot() async throws {
        let reading = MarketDetailsReadingFake()
        reading.result = .success(PerpsMarketDetails(
            metadata: makeMetadata(marketId: 7, symbol: "ETH", status: "paused", markPrice: 3421.72, fundingRatePercent: 0.00125),
            name: "Ethereum",
            iconURL: URL(string: "https://cdn.example.com/eth.png"),
            about: "Trade ETH"
        ))
        let service = PerpsMarketDetailsService(repository: reading)

        let snapshot = try await service.load(marketId: 7)

        XCTAssertEqual(reading.reloadedMarketIds, [7])
        XCTAssertEqual(snapshot.marketId, 7)
        XCTAssertEqual(snapshot.symbol, "ETH")
        XCTAssertEqual(snapshot.displayName, "Ethereum")
        XCTAssertEqual(snapshot.iconURL, URL(string: "https://cdn.example.com/eth.png"))
        XCTAssertEqual(snapshot.about, "Trade ETH")
        XCTAssertEqual(snapshot.price, 3421.72, accuracy: 1e-9)
        XCTAssertEqual(snapshot.fundingRatePercent ?? .nan, 0.00125, accuracy: 1e-9)
        XCTAssertFalse(snapshot.openEnabled)
        XCTAssertFalse(snapshot.isTradingEnabled)
    }

    func testLoad_mapsMissingMarketToNotFound() async {
        let reading = MarketDetailsReadingFake()
        reading.result = .failure(PerpsMarketsRepositoryError.marketNotFound)
        let service = PerpsMarketDetailsService(repository: reading)

        do {
            _ = try await service.load(marketId: 7)
            XCTFail("expected notFound")
        } catch PerpsMarketDetailsLoadError.notFound {
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testLoad_mapsOtherFailuresToFailed() async {
        let reading = MarketDetailsReadingFake()
        reading.result = .failure(URLError(.notConnectedToInternet))
        let service = PerpsMarketDetailsService(repository: reading)

        do {
            _ = try await service.load(marketId: 7)
            XCTFail("expected failed")
        } catch PerpsMarketDetailsLoadError.failed {
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

private func makeMetadata(
    marketId: Int64,
    symbol: String,
    status: String,
    markPrice: Double?,
    fundingRatePercent: Double?
) -> PerpsMarketMetadata {
    PerpsMarketMetadata(
        marketId: marketId,
        symbol: symbol,
        ticker: "\(symbol)/USD",
        status: status,
        markPrice: markPrice,
        lastTradePrice: nil,
        priceChangePercent: 4.37,
        volume24h: 1_023_874_500,
        openInterest: 48_213_900,
        maxLeverage: 40,
        fundingRatePercent: fundingRatePercent,
        priceDecimals: 2,
        sizeDecimals: 4,
        minBaseSize: 0.001
    )
}

private final class MarketDetailsReadingFake: PerpsMarketsReading, @unchecked Sendable {
    var result: Result<PerpsMarketDetails, Error> = .failure(PerpsMarketsRepositoryError.marketNotFound)
    private(set) var reloadedMarketIds: [Int64] = []

    func markets(query _: String?, sort _: PerpsMarketsSort, cursor _: String?) async throws -> PerpsMarketsPage {
        PerpsMarketsPage(items: [], nextCursor: nil)
    }

    func marketDetails(marketId _: Int64) async throws -> PerpsMarketDetails {
        XCTFail("the asset page must re-read details instead of serving the cache")
        return try result.get()
    }

    func reloadMarketDetails(marketId: Int64) async throws -> PerpsMarketDetails {
        reloadedMarketIds.append(marketId)
        return try result.get()
    }
}

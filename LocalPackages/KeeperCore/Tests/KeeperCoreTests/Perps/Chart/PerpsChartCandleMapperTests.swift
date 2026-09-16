@testable import KeeperCore
import TKKandelabrAPI
import XCTest

final class PerpsChartCandleMapperTests: XCTestCase {
    // MARK: Timeframe -> wire resolution

    func test_timeframe_wireMappingAndDisplayOrder() {
        XCTAssertEqual(PerpsChartTimeframe.m1.resolution, "1m")
        XCTAssertEqual(PerpsChartTimeframe.m5.resolution, "5m")
        XCTAssertEqual(PerpsChartTimeframe.m15.resolution, "15m")
        XCTAssertEqual(PerpsChartTimeframe.h1.resolution, "1h")
        XCTAssertEqual(PerpsChartTimeframe.h4.resolution, "4h")
        XCTAssertEqual(PerpsChartTimeframe.h12.resolution, "4h")
        XCTAssertEqual(PerpsChartTimeframe.d1.resolution, "1d")
        XCTAssertEqual(
            PerpsChartTimeframe.allCases.map(\.displayLabel),
            ["1M", "5M", "15M", "1H", "4H", "12H", "1D"]
        )
        XCTAssertEqual(PerpsChartTimeframe.h12.wireStepMilliseconds, 14_400_000)
    }

    func test_ticker_rewritesUSDCQuoteAndDefaultsUSD() {
        XCTAssertEqual(PerpsMarketTicker.make(base: "BTC", quote: "USDC"), "BTC/USD")
        XCTAssertEqual(PerpsMarketTicker.make(base: "ETH", quote: "USD"), "ETH/USD")
        XCTAssertEqual(PerpsMarketTicker.make(base: "SOL", quote: nil), "SOL/USD")
        XCTAssertEqual(PerpsMarketTicker.make(base: "TON", quote: ""), "TON/USD")
    }

    // MARK: Dense Kandelabr array

    func test_wireCandles_skipsEmptyAndKeepsDenseIndexTimestamps() {
        let batch = makeBatch(
            startTs: 1_700_000_000_000,
            candles: [
                makeWireCandle(close: "1"),
                makeWireCandle(close: "2", empty: true),
                makeWireCandle(close: "3"),
            ]
        )
        let mapped = PerpsChartCandleMapper.wireCandles(from: batch, timeframe: .m1)
        XCTAssertEqual(mapped.map { $0.openedAt.timeIntervalSince1970 }, [
            1_700_000_000,
            1_700_000_120,
        ])
        XCTAssertEqual(mapped.map(\.close), [1, 3])
    }

    func test_wireCandles_convertsBaseVolumeToQuote() throws {
        let batch = makeBatch(
            candles: [makeWireCandle(open: "2", high: "4", low: "1", close: "3", volume: "10")]
        )
        let mapped = try XCTUnwrap(PerpsChartCandleMapper.wireCandles(from: batch, timeframe: .h1).first)
        XCTAssertEqual(mapped.open, 2)
        XCTAssertEqual(mapped.high, 4)
        XCTAssertEqual(mapped.low, 1)
        XCTAssertEqual(mapped.close, 3)
        XCTAssertEqual(mapped.volume, 30)
    }

    func test_wireCandles_dropsInvalidPrices() {
        let batch = makeBatch(
            candles: [
                makeWireCandle(close: "0"),
                makeWireCandle(high: "1", low: "2"),
                makeWireCandle(close: "nan"),
                makeWireCandle(open: "1", high: "2", low: "1", close: "1.5"),
            ]
        )
        let mapped = PerpsChartCandleMapper.wireCandles(from: batch, timeframe: .h1)
        XCTAssertEqual(mapped.count, 1)
        XCTAssertEqual(mapped.first?.close, 1.5)
    }

    func test_matchesFeed_isCaseInsensitiveOnTicker() {
        let batch = makeBatch(ticker: "btc/usd", resolution: "1h")
        XCTAssertTrue(PerpsChartCandleMapper.matchesFeed(batch, ticker: "BTC/USD", timeframe: .h1))
        XCTAssertFalse(PerpsChartCandleMapper.matchesFeed(batch, ticker: "ETH/USD", timeframe: .h1))
        XCTAssertFalse(PerpsChartCandleMapper.matchesFeed(batch, ticker: "BTC/USD", timeframe: .m1))
    }

    // MARK: 12H aggregate of 4h bars

    func test_aggregateHalfDay_combinesThreeFourHourBars() {
        let fourHours: TimeInterval = 14400
        let bars = [
            PerpsChartCandle(openedAt: Date(timeIntervalSince1970: 0), open: 1, high: 10, low: 0.5, close: 2, volume: 1),
            PerpsChartCandle(openedAt: Date(timeIntervalSince1970: fourHours), open: 2, high: 11, low: 1.5, close: 3, volume: 2),
            PerpsChartCandle(openedAt: Date(timeIntervalSince1970: fourHours * 2), open: 3, high: 12, low: 2.5, close: 4, volume: 3),
        ]
        let aggregated = PerpsChartCandleMapper.published(bars, timeframe: .h12)
        XCTAssertEqual(aggregated.count, 1)
        XCTAssertEqual(aggregated[0].openedAt.timeIntervalSince1970, 0)
        XCTAssertEqual(aggregated[0].open, 1)
        XCTAssertEqual(aggregated[0].high, 12)
        XCTAssertEqual(aggregated[0].low, 0.5)
        XCTAssertEqual(aggregated[0].close, 4)
        XCTAssertEqual(aggregated[0].volume, 6)
    }

    func test_aggregateHalfDay_dropsIncompleteLeadingBucketWhenLaterBucketsExist() {
        let fourHours: TimeInterval = 14400
        let bars = [
            PerpsChartCandle(openedAt: Date(timeIntervalSince1970: 0), open: 1, high: 1, low: 1, close: 1, volume: 1),
            PerpsChartCandle(openedAt: Date(timeIntervalSince1970: fourHours * 3), open: 3, high: 3, low: 3, close: 3, volume: 1),
            PerpsChartCandle(openedAt: Date(timeIntervalSince1970: fourHours * 4), open: 4, high: 4, low: 4, close: 4, volume: 1),
            PerpsChartCandle(openedAt: Date(timeIntervalSince1970: fourHours * 5), open: 5, high: 5, low: 5, close: 5, volume: 1),
        ]
        let aggregated = PerpsChartCandleMapper.published(bars, timeframe: .h12)
        XCTAssertEqual(aggregated.count, 1)
        XCTAssertEqual(aggregated[0].openedAt.timeIntervalSince1970, 43200)
        XCTAssertEqual(aggregated[0].open, 3)
        XCTAssertEqual(aggregated[0].close, 5)
        let knownTimestamps = Set((0 ..< 6).map { Int64($0) * 14_400_000 })

        let withKnownEmptySlots = PerpsChartCandleMapper.published(
            bars,
            timeframe: .h12,
            knownTimestamps: knownTimestamps
        )

        XCTAssertEqual(withKnownEmptySlots.map(\.openedAt.timeIntervalSince1970), [0, fourHours * 3])
        XCTAssertEqual(withKnownEmptySlots.map(\.close), [1, 5])
    }
}

private extension PerpsChartCandleMapperTests {
    func makeBatch(
        ticker: String = "BTC/USD",
        resolution: String = "1h",
        startTs: Int64 = 1_700_000_000_000,
        candles: [TKKandelabrAPI.Components.Schemas.Candle] = []
    ) -> TKKandelabrAPI.Components.Schemas.GetCandlesResponse {
        .init(ticker: ticker, resolution: resolution, start_ts: startTs, candles: candles)
    }

    func makeWireCandle(
        open: String = "1",
        high: String = "2",
        low: String = "0.5",
        close: String = "1.5",
        volume: String = "100",
        empty: Bool? = nil
    ) -> TKKandelabrAPI.Components.Schemas.Candle {
        .init(o: open, h: high, l: low, c: close, v: volume, empty: empty)
    }
}

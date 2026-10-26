import LightweightCharts
@testable import Perps
import PerpsModels
import XCTest

@MainActor
final class PerpsChartRendererTests: XCTestCase {
    func test_isPriceUp_candleFollowsLastCandle_lineComparesRightmostWithLeftmostVisibleCandle() {
        let candles = [100.0, 120.0, 90.0, 110.0, 80.0, 90.0].enumerated().map { index, close in
            PerpsChartCandle(
                openedAt: Date(timeIntervalSince1970: TimeInterval((index + 1) * 1000)),
                open: close - 5, high: close + 1, low: close - 6, close: close, volume: nil
            )
        }
        let scrolledBack = FromToRange(from: 0.4, to: 2.3)

        XCTAssertEqual(PerpsChartRenderer.isPriceUp(candles, mode: .candle, visibleRange: scrolledBack), true)
        XCTAssertEqual(PerpsChartRenderer.isPriceUp(candles, mode: .line, visibleRange: nil), false)
        XCTAssertEqual(
            PerpsChartRenderer.isPriceUp(candles, mode: .line, visibleRange: scrolledBack),
            true,
            "the rightmost visible close decides, not the latest one"
        )
        XCTAssertEqual(
            PerpsChartRenderer.isPriceUp(candles, mode: .line, visibleRange: FromToRange(from: 2, to: 4.2)),
            true,
            "equal edges read as up"
        )
        XCTAssertEqual(PerpsChartRenderer.isPriceUp(candles, mode: .line, visibleRange: FromToRange(from: -0.5, to: 7)), false)
        XCTAssertNil(PerpsChartRenderer.isPriceUp([], mode: .line, visibleRange: nil))
    }

    func test_crosshair_mapsLocalChartTimeBackToCandleOpen() {
        let originalTimeZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(secondsFromGMT: 2 * 3600)!
        defer { NSTimeZone.default = originalTimeZone }

        let openedAt = Date(timeIntervalSince1970: 1_700_000_000)
        var crosshairTime: Date?
        let renderer = PerpsChartRenderer(onCrosshair: { time, _ in crosshairTime = time })
        renderer.render(
            candles: [PerpsChartCandle(openedAt: openedAt, open: 1, high: 1, low: 1, close: 1, volume: nil)],
            mode: .line,
            priceDecimals: 2,
            markers: [],
            timeframe: .m1,
            resolvedTheme: .dark
        )

        renderer.didCrosshairMove(
            onChart: LightweightCharts(options: ChartOptions()),
            parameters: MouseEventParams(
                time: .utc(timestamp: openedAt.timeIntervalSince1970 + 2 * 3600),
                logical: 0,
                point: Point(x: 0, y: 0),
                hoveredObjectId: nil,
                sourceEvent: nil,
                hoveredSeries: nil
            )
        )

        XCTAssertEqual(crosshairTime, openedAt)
    }
}

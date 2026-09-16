import Foundation
@testable import KeeperCore
import XCTest

final class PerpsChartTimelineTests: XCTestCase {
    func test_merge_replacesExistingCandleUnlessTimestampIsProtected() {
        let timestamp: Int64 = 1_700_000_000_000
        var timeline = PerpsChartTimeline(timeframe: .h1)

        timeline.merge(makeBatch([(timestamp, 100)]))
        timeline.merge(makeBatch([(timestamp, 110)]))
        XCTAssertEqual(timeline.publishedCandles.map(\.close), [110])

        timeline.merge(
            makeBatch([(timestamp, 120)]),
            preserving: [timestamp]
        )
        XCTAssertEqual(timeline.publishedCandles.map(\.close), [110])
    }

    func test_merge_usesWireTimestampsForContinuityAndTrimsAtRealGap() {
        let start: Int64 = 1_700_000_000_000
        let step = PerpsChartTimeframe.h1.wireStepMilliseconds
        var timeline = PerpsChartTimeline(timeframe: .h1)

        timeline.merge(makeBatch(
            [(start, 100), (start + 2 * step, 120)],
            wireTimestamps: [start, start + step, start + 2 * step]
        ))
        XCTAssertEqual(timeline.publishedCandles.map(\.close), [100, 120])

        timeline.merge(makeBatch([(start + 4 * step, 140)]))
        XCTAssertEqual(timeline.publishedCandles.map(\.close), [140])
        XCTAssertEqual(timeline.oldestTimestamp, start + 4 * step)
    }

    func test_merge_reportsGrowthOnlyWhenTimelineExtendsIntoPast() {
        let start: Int64 = 1_700_000_000_000
        let step = PerpsChartTimeframe.h1.wireStepMilliseconds
        var timeline = PerpsChartTimeline(timeframe: .h1)

        XCTAssertTrue(timeline.merge(makeBatch([(start, 100)])))
        XCTAssertFalse(timeline.merge(makeBatch([(start + step, 110)])))
        XCTAssertTrue(timeline.merge(makeBatch([(start - step, 90)])))
        XCTAssertEqual(timeline.publishedCandles.map(\.close), [90, 100, 110])
    }
}

private func makeBatch(
    _ values: [(timestamp: Int64, close: Double)],
    wireTimestamps: Set<Int64>? = nil
) -> PerpsChartCandleMapper.Batch {
    let candles = values.map { value in
        PerpsChartCandle(
            openedAt: Date(timeIntervalSince1970: Double(value.timestamp) / 1000),
            open: value.close,
            high: value.close,
            low: value.close,
            close: value.close,
            volume: nil
        )
    }
    let candleTimestamps = Set(values.map(\.timestamp))
    return PerpsChartCandleMapper.Batch(
        candles: candles,
        wireTimestamps: wireTimestamps ?? candleTimestamps,
        candleTimestamps: candleTimestamps
    )
}

import Foundation
import TKKandelabrAPI

/// Maps Kandelabr/Hermes candle buckets into stable `PerpsChartCandle`s.
///
/// The wire carries one bucket-aligned `start_ts` and a dense array: a bar's
/// time is `start_ts + index * wireStep`. Volume on the wire is base-asset;
/// the UI shows quote (USD) volume as `v * close`. Invalid bars are dropped.
/// `12H` aggregates every three 4h bars.
enum PerpsChartCandleMapper {
    struct Batch {
        let candles: [PerpsChartCandle]
        let wireTimestamps: Set<Int64>
        let candleTimestamps: Set<Int64>
    }

    static func wireCandles(
        from batch: Components.Schemas.GetCandlesResponse,
        timeframe: PerpsChartTimeframe
    ) -> [PerpsChartCandle] {
        mapBatch(from: batch, timeframe: timeframe).candles
    }

    static func mapBatch(
        from batch: Components.Schemas.GetCandlesResponse,
        timeframe: PerpsChartTimeframe
    ) -> Batch {
        let step = timeframe.wireStepMilliseconds
        var candles: [PerpsChartCandle] = []
        var wireTimestamps: Set<Int64> = []
        var candleTimestamps: Set<Int64> = []
        candles.reserveCapacity(batch.candles.count)
        wireTimestamps.reserveCapacity(batch.candles.count)
        candleTimestamps.reserveCapacity(batch.candles.count)
        for (index, candle) in batch.candles.enumerated() {
            guard let timestamp = wireTimestamp(startTs: batch.start_ts, index: index, step: step) else { continue }
            wireTimestamps.insert(timestamp)
            if let candle = map(candle, timestamp: timestamp) {
                candles.append(candle)
                candleTimestamps.insert(timestamp)
            }
        }
        return Batch(
            candles: candles,
            wireTimestamps: wireTimestamps,
            candleTimestamps: candleTimestamps
        )
    }

    static func published(
        _ candles: [PerpsChartCandle],
        timeframe: PerpsChartTimeframe,
        knownTimestamps: Set<Int64>? = nil
    ) -> [PerpsChartCandle] {
        timeframe == .h12 ? aggregateHalfDay(candles, knownTimestamps: knownTimestamps) : candles
    }

    static func matchesFeed(
        _ batch: Components.Schemas.GetCandlesResponse,
        ticker: String,
        timeframe: PerpsChartTimeframe
    ) -> Bool {
        batch.ticker.compare(ticker, options: .caseInsensitive) == .orderedSame
            && batch.resolution == timeframe.resolution
    }

    static func aggregateHalfDay(
        _ candles: [PerpsChartCandle],
        knownTimestamps: Set<Int64>? = nil
    ) -> [PerpsChartCandle] {
        let bucketSeconds: TimeInterval = 43200
        var buckets: [(candle: PerpsChartCandle, count: Int)] = []
        for candle in candles {
            let start = (candle.openedAt.timeIntervalSince1970 / bucketSeconds).rounded(.down) * bucketSeconds
            if let last = buckets.last, last.candle.openedAt.timeIntervalSince1970 == start {
                let volume: Double? = switch (last.candle.volume, candle.volume) {
                case let (lhs?, rhs?): lhs + rhs
                case let (lhs?, nil): lhs
                case let (nil, rhs?): rhs
                case (nil, nil): nil
                }
                buckets[buckets.index(before: buckets.endIndex)] = (
                    PerpsChartCandle(
                        openedAt: last.candle.openedAt,
                        open: last.candle.open,
                        high: max(last.candle.high, candle.high),
                        low: min(last.candle.low, candle.low),
                        close: candle.close,
                        volume: volume
                    ),
                    last.count + 1
                )
            } else {
                buckets.append((
                    PerpsChartCandle(
                        openedAt: Date(timeIntervalSince1970: start),
                        open: candle.open,
                        high: candle.high,
                        low: candle.low,
                        close: candle.close,
                        volume: candle.volume
                    ),
                    1
                ))
            }
        }
        let firstBucketIsComplete: Bool
        if let first = buckets.first, let knownTimestamps {
            let start = Int64((first.candle.openedAt.timeIntervalSince1970 * 1000).rounded())
            let step = PerpsChartTimeframe.h4.wireStepMilliseconds
            firstBucketIsComplete = (0 ..< 3).allSatisfy { knownTimestamps.contains(start + Int64($0) * step) }
        } else {
            firstBucketIsComplete = buckets.first?.count == 3
        }
        let firstIndex = buckets.count > 1 && !firstBucketIsComplete ? 1 : 0
        return buckets.dropFirst(firstIndex).map(\.candle)
    }

    private static func map(
        _ candle: Components.Schemas.Candle,
        timestamp: Int64
    ) -> PerpsChartCandle? {
        if candle.empty == true { return nil }
        guard let open = price(candle.o),
              let high = price(candle.h),
              let low = price(candle.l),
              let close = price(candle.c),
              high >= low
        else { return nil }
        let openedAt = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        guard openedAt.timeIntervalSince1970 > 0 else { return nil }
        guard let base = PerpsMarketMath.optionalDouble(candle.v), base.isFinite, base >= 0 else {
            return PerpsChartCandle(
                openedAt: openedAt,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: nil
            )
        }
        return PerpsChartCandle(
            openedAt: openedAt,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: base * close
        )
    }

    private static func wireTimestamp(startTs: Int64, index: Int, step: Int64) -> Int64? {
        let (offset, offsetOverflow) = Int64(index).multipliedReportingOverflow(by: step)
        guard !offsetOverflow else { return nil }
        let (timestamp, timestampOverflow) = startTs.addingReportingOverflow(offset)
        return timestampOverflow ? nil : timestamp
    }

    private static func price(_ raw: String?) -> Double? {
        guard let value = PerpsMarketMath.optionalDouble(raw), value.isFinite, value > 0 else { return nil }
        return value
    }
}

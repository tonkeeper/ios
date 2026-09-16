import Foundation

struct PerpsChartTimeline {
    private let timeframe: PerpsChartTimeframe
    private var bars: [PerpsChartCandle] = []
    private var knownTimestamps: Set<Int64> = []

    init(timeframe: PerpsChartTimeframe) {
        self.timeframe = timeframe
    }

    var isEmpty: Bool {
        bars.isEmpty
    }

    var oldestTimestamp: Int64? {
        knownTimestamps.min()
    }

    var candleTimestamps: Set<Int64> {
        Set(bars.map(timestamp))
    }

    var publishedCandles: [PerpsChartCandle] {
        PerpsChartCandleMapper.published(
            bars,
            timeframe: timeframe,
            knownTimestamps: knownTimestamps
        )
    }

    @discardableResult
    mutating func merge(
        _ incoming: PerpsChartCandleMapper.Batch,
        preserving protectedTimestamps: Set<Int64> = []
    ) -> Bool {
        let previousStart = oldestTimestamp
        let merged = mergeSorted(bars, incoming.candles, preserving: protectedTimestamps)
        knownTimestamps.formUnion(incoming.wireTimestamps)
        trimToLatestContinuousTimeline()
        bars = merged.filter { knownTimestamps.contains(timestamp($0)) }
        let currentStart = oldestTimestamp
        return switch (previousStart, currentStart) {
        case (nil, .some): true
        case let (previous?, current?): current < previous
        case (.some, nil), (nil, nil): false
        }
    }

    private func mergeSorted(
        _ current: [PerpsChartCandle],
        _ incoming: [PerpsChartCandle],
        preserving protectedTimestamps: Set<Int64>
    ) -> [PerpsChartCandle] {
        var result: [PerpsChartCandle] = []
        result.reserveCapacity(current.count + incoming.count)
        var currentIndex = 0
        var incomingIndex = 0
        while currentIndex < current.count, incomingIndex < incoming.count {
            let existing = current[currentIndex]
            let replacement = incoming[incomingIndex]
            let existingTime = timestamp(existing)
            let incomingTime = timestamp(replacement)
            if existingTime < incomingTime {
                result.append(existing)
                currentIndex += 1
            } else if incomingTime < existingTime {
                result.append(replacement)
                incomingIndex += 1
            } else {
                result.append(protectedTimestamps.contains(existingTime) ? existing : replacement)
                currentIndex += 1
                incomingIndex += 1
            }
        }
        result.append(contentsOf: current[currentIndex...])
        result.append(contentsOf: incoming[incomingIndex...])
        return result
    }

    private mutating func trimToLatestContinuousTimeline() {
        guard var start = knownTimestamps.max() else { return }
        while true {
            let (previous, overflow) = start.subtractingReportingOverflow(timeframe.wireStepMilliseconds)
            guard !overflow, knownTimestamps.contains(previous) else { break }
            start = previous
        }
        knownTimestamps = knownTimestamps.filter { $0 >= start }
    }

    private func timestamp(_ candle: PerpsChartCandle) -> Int64 {
        Int64((candle.openedAt.timeIntervalSince1970 * 1000).rounded())
    }
}

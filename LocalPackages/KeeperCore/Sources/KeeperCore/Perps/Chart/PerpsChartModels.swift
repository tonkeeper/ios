import Foundation

/// Chart timeframes in Figma row order. `displayLabel` is the UI label
/// (`1M`…`1D`, where `1M` is one minute — not one month); `resolution` is the
/// Kandelabr/Hermes wire value. `12H` rides the 4h feed and is aggregated
/// client-side — the backend has no 12h bucket.
public enum PerpsChartTimeframe: String, CaseIterable, Sendable {
    case m1
    case m5
    case m15
    case h1
    case h4
    case h12
    case d1

    public var displayLabel: String {
        switch self {
        case .m1: return "1M"
        case .m5: return "5M"
        case .m15: return "15M"
        case .h1: return "1H"
        case .h4: return "4H"
        case .h12: return "12H"
        case .d1: return "1D"
        }
    }

    public var resolution: String {
        switch self {
        case .m1: return "1m"
        case .m5: return "5m"
        case .m15: return "15m"
        case .h1: return "1h"
        case .h4, .h12: return "4h"
        case .d1: return "1d"
        }
    }

    public var wireStepMilliseconds: Int64 {
        switch self {
        case .m1: return 60000
        case .m5: return 300_000
        case .m15: return 900_000
        case .h1: return 3_600_000
        case .h4, .h12: return 14_400_000
        case .d1: return 86_400_000
        }
    }
}

/// One OHLCV bar in stable app units. Volume is quote (USD): the wire carries
/// base-asset volume, multiplied by close at map time.
public struct PerpsChartCandle: Equatable, Sendable {
    public let openedAt: Date
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double?

    public init(openedAt: Date, open: Double, high: Double, low: Double, close: Double, volume: Double?) {
        self.openedAt = openedAt
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}

public struct PerpsChartSnapshot: Equatable, Sendable {
    public let marketId: Int64
    public let timeframe: PerpsChartTimeframe
    public let candles: [PerpsChartCandle]
    public let priceDecimals: Int

    public init(
        marketId: Int64,
        timeframe: PerpsChartTimeframe,
        candles: [PerpsChartCandle],
        priceDecimals: Int
    ) {
        self.marketId = marketId
        self.timeframe = timeframe
        self.candles = candles
        self.priceDecimals = priceDecimals
    }
}

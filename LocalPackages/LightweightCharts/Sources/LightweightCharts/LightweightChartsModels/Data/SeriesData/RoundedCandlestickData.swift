import Foundation

public struct RoundedCandlestickData: OhlcData, Equatable, Sendable {
    public var time: Time
    public var open: Double?
    public var high: Double?
    public var low: Double?
    public var close: Double?
    public var color: ChartColor?
    public var wickColor: ChartColor?

    public init(
        time: Time,
        open: Double?,
        high: Double?,
        low: Double?,
        close: Double?,
        color: ChartColor? = nil,
        wickColor: ChartColor? = nil
    ) {
        self.time = time
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.color = color
        self.wickColor = wickColor
    }
}

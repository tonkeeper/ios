import Foundation

public struct RoundedHistogramData: SingleValueSeriesData, Equatable, Sendable {
    public var color: ChartColor?
    public var time: Time
    public var value: Double?

    public init(
        time: Time,
        value: Double?,
        color: ChartColor? = nil
    ) {
        self.time = time
        self.value = value
        self.color = color
    }
}

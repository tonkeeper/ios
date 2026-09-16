import Foundation

/**
 Represents a marker drawn above or below a data point to indicate a price change update.

 Used by the up-down markers plugin to show directional price movements on a series.
 */
public struct SeriesUpDownMarker: Codable, Sendable {
    /// The point on the horizontal scale.
    public var time: Time

    /// The price value for the data point.
    public var value: Double

    /// The direction of the price change.
    public var sign: MarkerSign

    public init(time: Time, value: Double, sign: MarkerSign) {
        self.time = time
        self.value = value
        self.sign = sign
    }
}

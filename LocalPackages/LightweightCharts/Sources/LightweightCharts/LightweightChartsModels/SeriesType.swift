import Foundation

public enum SeriesType: String, Codable, Sendable {
    case line = "Line"
    case area = "Area"
    case baseline = "Baseline"
    case candlestick = "Candlestick"
    case bar = "Bar"
    case histogram = "Histogram"
    case custom = "Custom"
}

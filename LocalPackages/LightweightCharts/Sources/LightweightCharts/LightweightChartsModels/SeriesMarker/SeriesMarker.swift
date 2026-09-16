import Foundation

public enum SeriesMarkerPosition: String, Codable, Sendable {
    case aboveBar
    case belowBar
    case inBar
    case atPriceTop
    case atPriceBottom
    case atPriceMiddle
}

// MARK: -

public enum SeriesMarkerShape: String, Codable, Sendable {
    case circle
    case square
    case arrowUp
    case arrowDown
}

// MARK: -

public struct SeriesMarker: Codable, Sendable {
    public var time: Time
    public var position: SeriesMarkerPosition
    public var shape: SeriesMarkerShape
    public var color: ChartColor
    public var id: String?
    public var text: String?
    public var size: Double?
    public var price: Double?

    public init(
        time: Time,
        position: SeriesMarkerPosition,
        shape: SeriesMarkerShape,
        color: ChartColor,
        id: String? = nil,
        text: String? = nil,
        size: Double? = nil,
        price: Double? = nil
    ) {
        self.time = time
        self.position = position
        self.shape = shape
        self.color = color
        self.id = id
        self.text = text
        self.size = size
        self.price = price
    }
}

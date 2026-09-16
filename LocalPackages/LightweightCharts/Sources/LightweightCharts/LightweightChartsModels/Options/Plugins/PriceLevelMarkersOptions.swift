import Foundation

public struct PriceLevelMarker: Codable, Sendable {
    public enum Alignment: String, Codable, Sendable {
        case left
        case right
    }

    public enum Direction: String, Codable, Sendable {
        case up
        case down
    }

    public var id: String
    public var price: Double
    public var title: String?
    public var color: ChartColor
    public var lineColor: ChartColor?
    public var backgroundColor: ChartColor?
    public var align: Alignment
    public var lineVisible: Bool?
    public var direction: Direction?
    /// Explicit flag so the JS layer detects the live-price marker without
    /// matching on a stringly-typed id.
    public var isCurrentPrice: Bool

    public init(
        id: String,
        price: Double,
        title: String?,
        color: ChartColor,
        lineColor: ChartColor? = nil,
        backgroundColor: ChartColor? = nil,
        align: Alignment,
        lineVisible: Bool? = nil,
        direction: Direction? = nil,
        isCurrentPrice: Bool = false
    ) {
        self.id = id
        self.price = price
        self.title = title
        self.color = color
        self.lineColor = lineColor
        self.backgroundColor = backgroundColor
        self.align = align
        self.lineVisible = lineVisible
        self.direction = direction
        self.isCurrentPrice = isCurrentPrice
    }
}

public struct PriceLevelMarkersOptions: Codable, Sendable {
    public enum AxisLabelMode: String, Codable, Sendable {
        /// Nice-stepped price ticks in the axis gutter (candle mode).
        case ladder
        /// Only the top/bottom price, overlaid over the full-width chart (line mode).
        case bounds
    }

    public var markers: [PriceLevelMarker]
    public var priceDecimals: Int?
    public var currentPriceUpLabelColor: ChartColor?
    public var currentPriceUpLabelBackgroundColor: ChartColor?
    public var currentPriceDownLabelColor: ChartColor?
    public var currentPriceDownLabelBackgroundColor: ChartColor?
    public var axisLabelColor: ChartColor?
    public var dotHaloColor: ChartColor?
    public var dotColor: ChartColor?
    public var crosshairColor: ChartColor?
    public var crosshairLabelColor: ChartColor?
    public var crosshairLabelBackgroundColor: ChartColor?
    public var gridColor: ChartColor?
    public var axisLabelMode: AxisLabelMode?
    public var crosshairHorizontalVisible: Bool?
    public var crosshairLabelVisible: Bool?
    public var crosshairDotOnSeries: Bool?

    public init(
        markers: [PriceLevelMarker] = [],
        priceDecimals: Int? = nil,
        currentPriceUpLabelColor: ChartColor? = nil,
        currentPriceUpLabelBackgroundColor: ChartColor? = nil,
        currentPriceDownLabelColor: ChartColor? = nil,
        currentPriceDownLabelBackgroundColor: ChartColor? = nil,
        axisLabelColor: ChartColor? = nil,
        dotHaloColor: ChartColor? = nil,
        dotColor: ChartColor? = nil,
        crosshairColor: ChartColor? = nil,
        crosshairLabelColor: ChartColor? = nil,
        crosshairLabelBackgroundColor: ChartColor? = nil,
        gridColor: ChartColor? = nil,
        axisLabelMode: AxisLabelMode? = nil,
        crosshairHorizontalVisible: Bool? = nil,
        crosshairLabelVisible: Bool? = nil,
        crosshairDotOnSeries: Bool? = nil
    ) {
        self.markers = markers
        self.priceDecimals = priceDecimals
        self.currentPriceUpLabelColor = currentPriceUpLabelColor
        self.currentPriceUpLabelBackgroundColor = currentPriceUpLabelBackgroundColor
        self.currentPriceDownLabelColor = currentPriceDownLabelColor
        self.currentPriceDownLabelBackgroundColor = currentPriceDownLabelBackgroundColor
        self.axisLabelColor = axisLabelColor
        self.dotHaloColor = dotHaloColor
        self.dotColor = dotColor
        self.crosshairColor = crosshairColor
        self.crosshairLabelColor = crosshairLabelColor
        self.crosshairLabelBackgroundColor = crosshairLabelBackgroundColor
        self.gridColor = gridColor
        self.axisLabelMode = axisLabelMode
        self.crosshairHorizontalVisible = crosshairHorizontalVisible
        self.crosshairLabelVisible = crosshairLabelVisible
        self.crosshairDotOnSeries = crosshairDotOnSeries
    }
}

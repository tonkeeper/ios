import Foundation

public enum PerpsChartLoadingState: Equatable {
    case loading
    case ready
    case empty
    case failed
    case reconnecting
}

/// Change of the selected point against the close of the leftmost visible candle.
public struct PerpsChartSelectedChange: Equatable {
    public let percent: Double
    public let amount: Double
    public let isPositive: Bool

    public init(percent: Double, amount: Double, isPositive: Bool) {
        self.percent = percent
        self.amount = amount
        self.isPositive = isPositive
    }
}

/// Crosshair values arrive pre-formatted: the numbers are venue amounts, and the
/// formatter that renders them lives on the bound side of the module.
public struct PerpsChartCrosshairReadout: Equatable {
    public let dateTime: String
    public let openText: String
    public let closeText: String
    public let percentText: String
    public let amountText: String
    public let volumeText: String
    public let highText: String
    public let lowText: String
    public let isPositive: Bool

    public init(
        dateTime: String,
        openText: String,
        closeText: String,
        percentText: String,
        amountText: String,
        volumeText: String,
        highText: String,
        lowText: String,
        isPositive: Bool
    ) {
        self.dateTime = dateTime
        self.openText = openText
        self.closeText = closeText
        self.percentText = percentText
        self.amountText = amountText
        self.volumeText = volumeText
        self.highText = highText
        self.lowText = lowText
        self.isPositive = isPositive
    }
}

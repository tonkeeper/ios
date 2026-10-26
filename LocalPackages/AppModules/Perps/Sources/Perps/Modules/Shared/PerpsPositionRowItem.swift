import Foundation

public struct PerpsPositionRowItem: Identifiable, Equatable {
    public let id: Int64
    let symbol: String
    let iconURL: URL?
    let leverageText: String?
    let sideText: String
    let isLong: Bool
    let valueText: String
    let pnlText: String
    /// `nil` when the PnL is hidden, so its color does not reveal the sign.
    let isPnlPositive: Bool?

    public init(
        id: Int64,
        symbol: String,
        iconURL: URL?,
        leverageText: String?,
        sideText: String,
        isLong: Bool,
        valueText: String,
        pnlText: String,
        isPnlPositive: Bool?
    ) {
        self.id = id
        self.symbol = symbol
        self.iconURL = iconURL
        self.leverageText = leverageText
        self.sideText = sideText
        self.isLong = isLong
        self.valueText = valueText
        self.pnlText = pnlText
        self.isPnlPositive = isPnlPositive
    }
}

public struct PerpsPositionsTotal: Equatable {
    let amountText: String
    let pnlText: String
    let pnlPercentText: String?
    let isPnlPositive: Bool

    public init(amountText: String, pnlText: String, pnlPercentText: String?, isPnlPositive: Bool) {
        self.amountText = amountText
        self.pnlText = pnlText
        self.pnlPercentText = pnlPercentText
        self.isPnlPositive = isPnlPositive
    }
}

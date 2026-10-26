import Foundation

public struct PerpsLimitOrderRowItem: Identifiable, Equatable {
    public var id: String {
        "\(marketId):\(orderIndex)"
    }

    let orderIndex: Int64
    let marketId: Int64
    let symbol: String
    let iconURL: URL?
    let sideText: String
    let isLong: Bool
    let valueText: String
    let limitText: String

    public init(
        orderIndex: Int64,
        marketId: Int64,
        symbol: String,
        iconURL: URL?,
        sideText: String,
        isLong: Bool,
        valueText: String,
        limitText: String
    ) {
        self.orderIndex = orderIndex
        self.marketId = marketId
        self.symbol = symbol
        self.iconURL = iconURL
        self.sideText = sideText
        self.isLong = isLong
        self.valueText = valueText
        self.limitText = limitText
    }
}

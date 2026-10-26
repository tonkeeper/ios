import Foundation

public struct PerpsMarketRowItem: Identifiable, Equatable {
    public let id: Int64
    let symbol: String
    let iconURL: URL?
    let leverageText: String?
    let volumeText: String
    let priceText: String
    let changeText: String
    let isChangePositive: Bool

    public init(
        id: Int64,
        symbol: String,
        iconURL: URL?,
        leverageText: String?,
        volumeText: String,
        priceText: String,
        changeText: String,
        isChangePositive: Bool
    ) {
        self.id = id
        self.symbol = symbol
        self.iconURL = iconURL
        self.leverageText = leverageText
        self.volumeText = volumeText
        self.priceText = priceText
        self.changeText = changeText
        self.isChangePositive = isChangePositive
    }
}

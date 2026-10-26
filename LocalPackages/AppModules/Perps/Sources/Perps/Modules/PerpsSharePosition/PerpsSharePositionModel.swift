import Foundation
import TKLocalize

public struct SharePositionSnapshot: Equatable {
    public let coinName: String
    public let iconLetter: String
    public let iconURL: URL?
    public let isLong: Bool
    public let leverage: Double?
    public let entryPrice: Double
    public let currentPrice: Double
    public let pnlPercent: Double?
    public let isProfit: Bool
    public let date: Date

    public init(
        coinName: String,
        iconLetter: String,
        iconURL: URL?,
        isLong: Bool,
        leverage: Double?,
        entryPrice: Double,
        currentPrice: Double,
        pnlPercent: Double?,
        isProfit: Bool,
        date: Date
    ) {
        self.coinName = coinName
        self.iconLetter = iconLetter
        self.iconURL = iconURL
        self.isLong = isLong
        self.leverage = leverage
        self.entryPrice = entryPrice
        self.currentPrice = currentPrice
        self.pnlPercent = pnlPercent
        self.isProfit = isProfit
        self.date = date
    }
}

public enum PerpsSharePositionPresenter {
    public static func model(from snapshot: SharePositionSnapshot, format: PerpsFormatting) -> PerpsSharePositionCardModel {
        PerpsSharePositionCardModel(
            coinName: snapshot.coinName,
            iconLetter: snapshot.iconLetter,
            iconURL: snapshot.iconURL,
            iconImage: nil,
            leverageText: snapshot.leverage.map { format.leverage($0).uppercased() },
            sideText: (snapshot.isLong ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased(),
            isProfit: snapshot.isProfit,
            pnlPercentText: snapshot.pnlPercent.map { format.signedPercent($0) },
            entryText: format.usd(snapshot.entryPrice),
            currentText: format.usd(snapshot.currentPrice),
            dateText: format.candleDateTime(snapshot.date)
        )
    }
}

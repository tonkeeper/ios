import Foundation
import TKLocalize
import UIKit

struct SharePositionSnapshot: Equatable {
    let coinName: String
    let iconLetter: String
    let iconURL: URL?
    let isLong: Bool
    let leverage: Double?
    let entryPrice: Double
    let currentPrice: Double
    let pnlPercent: Double?
    let isProfit: Bool
    let date: Date
}

struct PerpsSharePositionCardModel: Equatable {
    let coinName: String
    let iconLetter: String
    var iconURL: URL?
    var iconImage: UIImage?
    let leverageText: String?
    let sideText: String
    let isProfit: Bool
    let pnlPercentText: String?
    let entryText: String
    let currentText: String
    let dateText: String

    func withLoadedIcon(_ image: UIImage?) -> PerpsSharePositionCardModel {
        var model = self
        model.iconImage = image
        model.iconURL = image == nil ? nil : iconURL
        return model
    }
}

enum PerpsSharePositionPresenter {
    static func model(from snapshot: SharePositionSnapshot) -> PerpsSharePositionCardModel {
        PerpsSharePositionCardModel(
            coinName: snapshot.coinName,
            iconLetter: snapshot.iconLetter,
            iconURL: snapshot.iconURL,
            iconImage: nil,
            leverageText: snapshot.leverage.map { PerpsFormatting.leverage($0).uppercased() },
            sideText: (snapshot.isLong ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased(),
            isProfit: snapshot.isProfit,
            pnlPercentText: snapshot.pnlPercent.map { PerpsFormatting.signedPercent($0) },
            entryText: PerpsFormatting.usdWhole(snapshot.entryPrice),
            currentText: PerpsFormatting.usdWhole(snapshot.currentPrice),
            dateText: PerpsFormatting.candleDateTime(snapshot.date)
        )
    }
}

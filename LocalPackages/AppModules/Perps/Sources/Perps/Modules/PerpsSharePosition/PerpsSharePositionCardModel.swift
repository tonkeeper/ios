import Foundation
import UIKit

public struct PerpsSharePositionCardModel: Equatable {
    public let coinName: String
    public let iconLetter: String
    var iconURL: URL?
    var iconImage: UIImage?
    public let leverageText: String?
    public let sideText: String
    public let isProfit: Bool
    public let pnlPercentText: String?
    public let entryText: String
    public let currentText: String
    public let dateText: String

    public init(
        coinName: String,
        iconLetter: String,
        iconURL: URL?,
        iconImage: UIImage?,
        leverageText: String?,
        sideText: String,
        isProfit: Bool,
        pnlPercentText: String?,
        entryText: String,
        currentText: String,
        dateText: String
    ) {
        self.coinName = coinName
        self.iconLetter = iconLetter
        self.iconURL = iconURL
        self.iconImage = iconImage
        self.leverageText = leverageText
        self.sideText = sideText
        self.isProfit = isProfit
        self.pnlPercentText = pnlPercentText
        self.entryText = entryText
        self.currentText = currentText
        self.dateText = dateText
    }

    func withLoadedIcon(_ image: UIImage?) -> PerpsSharePositionCardModel {
        var model = self
        model.iconImage = image
        model.iconURL = image == nil ? nil : iconURL
        return model
    }
}

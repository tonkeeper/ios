import Foundation
import TKUIKit

public enum PredictionsSectionState: Equatable, Sendable {
    case loading
    case cards(balance: String?, cards: [PredictionCardViewData])
}

public enum PredictionOutcome: Equatable, Sendable {
    case yes
    case no
}

public struct PredictionCardViewData: Identifiable, Equatable, Sendable {
    public enum Subtitle: Equatable, Sendable {
        case text(String)
        case countdown(String, endsAt: Date)
    }

    public enum Footer: Equatable, Sendable {
        case outcomes(yes: String, no: String)
        case position(PredictionPositionViewData)
    }

    public let id: String
    public let imageSource: AssetAvatarViewImageSource
    public let title: String
    public let subtitle: Subtitle
    public let footer: Footer

    public init(
        id: String,
        imageSource: AssetAvatarViewImageSource,
        title: String,
        subtitle: Subtitle,
        footer: Footer
    ) {
        self.id = id
        self.imageSource = imageSource
        self.title = title
        self.subtitle = subtitle
        self.footer = footer
    }
}

public struct PredictionPositionViewData: Equatable, Sendable {
    public let title: String
    public let titleColor: TKColor
    public let amount: String
    public let change: String
    public let changeColor: TKColor

    public init(
        title: String,
        titleColor: TKColor,
        amount: String,
        change: String,
        changeColor: TKColor
    ) {
        self.title = title
        self.titleColor = titleColor
        self.amount = amount
        self.change = change
        self.changeColor = changeColor
    }
}

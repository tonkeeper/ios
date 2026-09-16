import TKUIKit
import UIKit

public struct OnboardingInfoScreenState {
    public let icon: UIImage?
    public let iconTintColor: TKColor
    public let title: String
    public let subtitle: String
    public let buttonTitle: String

    public init(
        icon: UIImage?,
        iconTintColor: TKColor = .iconPrimary,
        title: String,
        subtitle: String,
        buttonTitle: String
    ) {
        self.icon = icon
        self.iconTintColor = iconTintColor
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
    }
}

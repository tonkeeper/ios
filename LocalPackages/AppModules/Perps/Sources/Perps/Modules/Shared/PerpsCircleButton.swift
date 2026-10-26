import SwiftUI
import TKUIKit

public struct PerpsCircleButton: View {
    public enum Appearance {
        case secondary
        case neutral
        case accent

        var icon: TKColor {
            switch self {
            case .secondary: .iconSecondary
            case .neutral: .iconPrimary
            case .accent: .buttonPrimaryForeground
            }
        }

        var background: TKColor {
            switch self {
            case .secondary, .neutral: .backgroundContentTint
            case .accent: .buttonPrimaryBackground
            }
        }
    }

    let icon: UIImage
    var appearance: Appearance = .secondary
    var side: CGFloat = 32
    let action: () -> Void

    public init(icon: UIImage, appearance: Appearance = .secondary, side: CGFloat = 32, action: @escaping () -> Void) {
        self.icon = icon
        self.appearance = appearance
        self.side = side
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            SwiftUI.Image(uiImage: icon)
                .renderingMode(.template)
                .foregroundStyle(appearance.icon)
                .frame(width: side, height: side)
                .background(appearance.background)
                .clipShape(Circle())
        }
    }
}

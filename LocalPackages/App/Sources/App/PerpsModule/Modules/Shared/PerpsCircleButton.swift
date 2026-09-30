import SwiftUI
import TKUIKit

struct PerpsCircleButton: View {
    enum Appearance {
        case secondary
        case accent

        var icon: TKColor {
            switch self {
            case .secondary: .iconSecondary
            case .accent: .buttonPrimaryForeground
            }
        }

        var background: TKColor {
            switch self {
            case .secondary: .backgroundContentTint
            case .accent: .buttonPrimaryBackground
            }
        }
    }

    let icon: UIImage
    var appearance: Appearance = .secondary
    var side: CGFloat = 32
    let action: () -> Void

    var body: some View {
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

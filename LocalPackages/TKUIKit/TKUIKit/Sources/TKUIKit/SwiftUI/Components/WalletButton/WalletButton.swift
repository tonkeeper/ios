import SwiftUI

public struct WalletButtonConfig: Hashable {
    public enum Icon: Hashable {
        case emoji(String)
        case image(UIImage?)
    }

    public var title: String
    public var icon: Icon
    public var color: TKColor

    public init(
        title: String,
        icon: Icon,
        color: TKColor
    ) {
        self.title = title
        self.icon = icon
        self.color = color
    }
}

public struct WalletButton: View {
    @Environment(\.tkPalette) private var palette

    public var config: WalletButtonConfig
    private let haptic: TKTapAnimationHaptic
    private let action: () -> Void

    public init(
        config: WalletButtonConfig,
        haptic: TKTapAnimationHaptic = .none,
        action: @escaping () -> Void
    ) {
        self.config = config
        self.haptic = haptic
        self.action = action
    }

    public var body: some View {
        SwiftUI.Button(action: action) {
            content
        }
        .buttonStyle(
            WalletButtonStyle(
                backgroundColor: backgroundColor,
                haptic: haptic
            )
        )
        .accessibilityLabel(config.title)
    }
}

private extension WalletButton {
    var content: some View {
        HStack(spacing: 0) {
            iconView

            Text(config.title)
                .textStyle(Layout.titleTextStyle)
                .foregroundStyle(foregroundColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, Layout.iconTitleSpacing)

            SwiftUI.Image.TKUIKit.Icons.Size16.chevronDown
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    foregroundColor
                        .opacity(Layout.chevronOpacity)
                )
                .frame(
                    width: Layout.chevronSize,
                    height: Layout.chevronSize
                )
                .padding(.leading, Layout.titleChevronSpacing)
        }
        .padding(Layout.contentInsets)
    }

    @ViewBuilder
    var iconView: some View {
        switch config.icon {
        case let .emoji(emoji):
            Text(emoji)
                .font(Layout.emojiFont)
                .lineLimit(1)
        case let .image(image):
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foregroundColor)
                    .frame(
                        width: Layout.iconSize,
                        height: Layout.iconSize
                    )
            } else {
                Color.clear
                    .frame(
                        width: Layout.iconSize,
                        height: Layout.iconSize
                    )
            }
        }
    }

    var backgroundColor: Color {
        config.color.resolve(palette)
    }

    var foregroundColor: Color {
        .white
    }
}

private struct WalletButtonStyle: SwiftUI.ButtonStyle {
    var backgroundColor: Color
    var haptic: TKTapAnimationHaptic

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .contentShape(Capsule())
            .tkTapAnimation(isPressed: configuration.isPressed, haptic: haptic)
    }
}

extension WalletButton {
    enum Layout {
        static let contentInsets = EdgeInsets(
            top: 10,
            leading: 11,
            bottom: 10,
            trailing: 12
        )
        static let iconSize: CGFloat = 20
        static let chevronSize: CGFloat = 16
        static let iconTitleSpacing: CGFloat = 5
        static let titleChevronSpacing: CGFloat = 6
        static let chevronOpacity: CGFloat = 0.64
        static let titleTextStyle: TKTextStyle = .label2
        static let emojiFont: Font = .system(size: 17)
    }
}

import SwiftUI

public struct WalletConnectNetworksSummaryCellContent {
    public let icons: [UIImage]

    public init(icons: [UIImage]) {
        self.icons = icons
    }
}

public struct WalletConnectNetworksSummaryCell: View {
    @Environment(\.tkPalette) private var palette

    public let content: WalletConnectNetworksSummaryCellContent
    public let action: () -> Void

    public init(
        content: WalletConnectNetworksSummaryCellContent,
        action: @escaping () -> Void
    ) {
        self.content = content
        self.action = action
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                action: action
            ),
            leading: {
                HStack(spacing: Layout.iconsSpacing) {
                    ForEach(Array(visibleIcons.enumerated()), id: \.offset) { offset, icon in
                        iconView(icon)
                            .zIndex(Double(visibleIcons.count - offset))
                    }

                    if showsMoreIcon {
                        moreIconView
                    }
                }
                .padding(.leading, Layout.leadingPadding)
                .padding(.vertical, Layout.verticalPadding)
            },
            center: {
                Spacer()
            },
            trailing: {
                CellTrailingAccessory(
                    config: CellTrailingAccessory.Config(
                        color: .iconTertiary,
                        icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                        iconSize: Layout.chevronSize
                    )
                )
            }
        )
    }

    private var visibleIcons: [UIImage] {
        if content.icons.count > Layout.maxVisibleIcons {
            return Array(content.icons.prefix(Layout.maxVisibleIcons - 1))
        }
        return content.icons
    }

    private var showsMoreIcon: Bool {
        content.icons.count > Layout.maxVisibleIcons
    }

    private func iconView(_ icon: UIImage) -> some View {
        Image(uiImage: icon)
            .resizable()
            .scaledToFit()
            .frame(width: Layout.iconSize, height: Layout.iconSize)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(palette.background.content, lineWidth: Layout.borderWidth)
            }
    }

    private var moreIconView: some View {
        Circle()
            .fill(.backgroundContentTint)
            .frame(width: Layout.iconSize, height: Layout.iconSize)
            .overlay {
                SwiftUI.Image.TKUIKit.Icons.Size16.ellipses
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.iconSecondary)
                    .frame(width: Layout.moreIconSize, height: Layout.moreIconSize)
            }
            .overlay {
                Circle()
                    .strokeBorder(palette.background.content, lineWidth: Layout.borderWidth)
            }
    }
}

private extension WalletConnectNetworksSummaryCell {
    enum Layout {
        static let iconSize: CGFloat = 28
        static let moreIconSize: CGFloat = 14
        static let chevronSize: CGFloat = 16
        static let borderWidth: CGFloat = 2
        static let leadingPadding: CGFloat = 14
        static let verticalPadding: CGFloat = 14
        static let iconsSpacing: CGFloat = -8
        static let maxVisibleIcons = 7
    }
}

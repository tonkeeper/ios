import SwiftUI
import TKLocalize
import TKUIKit

struct WalletBalanceMoreAssetsCell: View {
    let previewAvatars: [AssetAvatarViewImageSource]
    let showsDivider: Bool
    let action: (() -> Void)?

    var body: some View {
        Cell(
            config: Cell.Config(
                style: .grouped,
                showsDivider: showsDivider,
                verticalAlignment: .center,
                action: action
            ),
            leading: {
                leadingView
            },
            center: {
                centerView
            },
            trailing: {
                EmptyView()
            }
        )
        .frame(height: Layout.rowHeight)
    }

    private var leadingView: some View {
        WalletBalanceMoreAssetsPreviewAvatarsView(sources: previewAvatars)
            .frame(width: Layout.leadingContentWidth, height: Layout.avatarHeight)
            .padding(.leading, Layout.horizontalInset)
            .frame(height: Layout.rowHeight, alignment: .center)
    }

    private var centerView: some View {
        titleRow
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Layout.centerLeadingInset)
            .padding(.trailing, Layout.horizontalInset)
            .frame(height: Layout.rowHeight, alignment: .center)
    }

    private var titleRow: some View {
        HStack(spacing: Layout.titleChevronSpacing) {
            Text(title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            SwiftUI.Image.TKUIKit.Icons.Size16.chevronDown
                .resizable()
                .scaledToFit()
                .frame(width: Layout.chevronSize, height: Layout.chevronSize)
                .foregroundStyle(.iconTertiary)
        }
    }
}

private extension WalletBalanceMoreAssetsCell {
    enum Layout {
        static let rowHeight: CGFloat = 56
        static let horizontalInset: CGFloat = 16
        static let centerLeadingInset: CGFloat = 16
        static let leadingContentWidth: CGFloat = 44
        static let avatarHeight: CGFloat = 28
        static let titleChevronSpacing: CGFloat = 4
        static let chevronSize: CGFloat = 16
    }

    var title: String {
        TKLocales.WalletBalanceList.MoreAssets.title
    }
}

private struct WalletBalanceMoreAssetsPreviewAvatarsView: View {
    let sources: [AssetAvatarViewImageSource]
    @Environment(\.tkPalette) private var palette

    var body: some View {
        Group {
            if sources.count >= 2 {
                HStack(spacing: Layout.overlapSpacing) {
                    avatarView(sources[0])
                        .zIndex(1)
                    avatarView(sources[1])
                }
            } else if let source = sources.first {
                avatarView(source)
            }
        }
    }

    private func avatarView(_ source: AssetAvatarViewImageSource) -> some View {
        AssetAvatarView(
            imageSource: source,
            configuration: Layout.avatarConfiguration
        )
        .overlay {
            Circle()
                .strokeBorder(palette.background.content, lineWidth: Layout.borderWidth)
        }
    }
}

private extension WalletBalanceMoreAssetsPreviewAvatarsView {
    enum Layout {
        static let avatarSize: CGFloat = 28
        static let borderWidth: CGFloat = 2
        static let overlapSpacing: CGFloat = -10

        static var avatarConfiguration: AssetAvatarView.Configuration {
            AssetAvatarView.Configuration(
                imageSize: avatarSize,
                chainIconSize: 0,
                chainIconPadding: 0,
                chainIconOffsetX: 0,
                chainIconOffsetY: 0
            )
        }
    }
}

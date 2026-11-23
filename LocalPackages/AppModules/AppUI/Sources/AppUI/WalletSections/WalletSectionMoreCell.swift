import SwiftUI
import TKLocalize
import TKUIKit

public struct WalletSectionMoreCell: View {
    private let title: String
    private let previewAvatars: [AssetAvatarViewImageSource]
    private let limit: WalletSectionLimit
    private let showsDivider: Bool
    private let limitMenuIdentifier: String
    private let onTap: () -> Void
    private let onSelectLimit: (WalletSectionLimit) -> Void

    public init(
        title: String,
        previewAvatars: [AssetAvatarViewImageSource],
        limit: WalletSectionLimit,
        showsDivider: Bool,
        limitMenuIdentifier: String,
        onTap: @escaping () -> Void,
        onSelectLimit: @escaping (WalletSectionLimit) -> Void
    ) {
        self.title = title
        self.previewAvatars = previewAvatars
        self.limit = limit
        self.showsDivider = showsDivider
        self.limitMenuIdentifier = limitMenuIdentifier
        self.onTap = onTap
        self.onSelectLimit = onSelectLimit
    }

    public var body: some View {
        Cell(
            config: Cell.Config(
                style: .grouped,
                showsDivider: showsDivider,
                verticalAlignment: .center
            ),
            leading: {
                EmptyView()
            },
            center: {
                openButton
            },
            trailing: {
                limitMenu
            }
        )
        .frame(height: Layout.rowHeight)
    }

    private var openButton: some View {
        Button(action: onTap) {
            HStack(spacing: Layout.avatarsTitleSpacing) {
                if !previewAvatars.isEmpty {
                    WalletSectionMoreAvatarsView(sources: previewAvatars)
                }
                HStack(spacing: Layout.titleChevronSpacing) {
                    Text(title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight
                        .resizable()
                        .scaledToFit()
                        .frame(width: Layout.chevronSize, height: Layout.chevronSize)
                        .foregroundStyle(.iconTertiary)
                }
            }
            .padding(.leading, Layout.horizontalInset)
            .padding(.trailing, Layout.horizontalInset)
            .frame(maxWidth: .infinity, minHeight: Layout.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(TKTapAnimationButtonStyle())
    }

    private var limitMenu: some View {
        Menu {
            ForEach(WalletSectionLimit.allCases) { item in
                Button {
                    onSelectLimit(item)
                } label: {
                    let title = TKLocales.WalletBalanceList.SectionLimit.top(item.count)
                    if item == limit {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            SwiftUI.Image.TKUIKit.Icons.Size28.ellipses
                .resizable()
                .scaledToFit()
                .frame(width: Layout.ellipsisSize, height: Layout.ellipsisSize)
                .foregroundStyle(.iconSecondary)
                .padding(.trailing, Layout.horizontalInset)
                .frame(height: Layout.rowHeight)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier(limitMenuIdentifier)
    }
}

private struct WalletSectionMoreAvatarsView: View {
    let sources: [AssetAvatarViewImageSource]

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(sources.prefix(Layout.maxPreviewAvatars).enumerated()), id: \.offset) { index, source in
                avatar(source, isFirst: index == 0)
                    .padding(.leading, CGFloat(index) * Layout.avatarStep)
            }
        }
    }

    private func avatar(_ source: AssetAvatarViewImageSource, isFirst: Bool) -> some View {
        AssetAvatarView(
            imageSource: source.withoutChainIcon,
            configuration: isFirst ? Layout.firstAvatar : Layout.nextAvatar
        )
        .frame(width: Layout.avatarSize, height: Layout.avatarSize)
        .background(Circle().fill(.backgroundContent))
    }
}

private extension AssetAvatarViewImageSource {
    var withoutChainIcon: AssetAvatarViewImageSource {
        switch self {
        case let .url(url, _):
            .url(url)
        case let .image(image, _):
            .image(image)
        case .shimmer:
            .shimmer
        }
    }
}

private enum Layout {
    static let rowHeight: CGFloat = 56
    static let horizontalInset: CGFloat = 16
    static let avatarsTitleSpacing: CGFloat = 16
    static let titleChevronSpacing: CGFloat = 4
    static let chevronSize: CGFloat = 16
    static let ellipsisSize: CGFloat = 28
    static let maxPreviewAvatars = 2
    static let avatarSize: CGFloat = 24
    static let avatarRing: CGFloat = 2
    static let avatarStep: CGFloat = 20
    static let firstAvatar = avatarConfiguration(imageSize: avatarSize)
    static let nextAvatar = avatarConfiguration(imageSize: avatarSize - avatarRing * 2)

    static func avatarConfiguration(imageSize: CGFloat) -> AssetAvatarView.Configuration {
        AssetAvatarView.Configuration(
            imageSize: imageSize,
            chainIconSize: 0,
            chainIconPadding: 0,
            chainIconOffsetX: 0,
            chainIconOffsetY: 0
        )
    }
}

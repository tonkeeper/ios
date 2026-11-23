import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsMorePositionsRow: View {
    let more: PerpsMorePositions

    var body: some View {
        HStack(spacing: Layout.iconsTitleSpacing) {
            HStack(spacing: Layout.iconOverlap) {
                ForEach(Array(more.iconURLs.enumerated()), id: \.offset) { index, url in
                    icon(url)
                        .zIndex(Double(more.iconURLs.count - index))
                }
            }
            .frame(width: Layout.iconsWidth, alignment: .leading)
            HStack(spacing: Layout.titleChevronSpacing) {
                Text(TKLocales.Perps.morePositions)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                    .renderingMode(.template)
                    .foregroundStyle(.iconTertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.rowHeight, alignment: .leading)
        .padding(.horizontal, Layout.horizontalInset)
    }

    private func icon(_ url: URL?) -> some View {
        Group {
            if let url {
                AssetAvatarView(imageSource: .url(url), configuration: Layout.avatar)
            } else {
                Circle().fill(.backgroundContentTint)
            }
        }
        .frame(width: Layout.iconSize, height: Layout.iconSize)
        .overlay(Circle().strokeBorder(.backgroundContent, lineWidth: Layout.iconBorder))
    }
}

private enum Layout {
    static let rowHeight: CGFloat = 56
    static let horizontalInset: CGFloat = 16
    static let iconsWidth: CGFloat = 44
    static let iconsTitleSpacing: CGFloat = 16
    static let iconSize: CGFloat = 28
    static let iconBorder: CGFloat = 2
    static let iconOverlap: CGFloat = -10
    static let titleChevronSpacing: CGFloat = 4
    static let avatar = AssetAvatarView.Configuration(
        imageSize: iconSize,
        chainIconSize: 0,
        chainIconPadding: 0,
        chainIconOffsetX: 0,
        chainIconOffsetY: 0
    )
}

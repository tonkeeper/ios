import SwiftUI
import TKUIKit

struct RampPaymentMethodCell: View {
    @Environment(\.tkPalette) private var palette
    let row: RampPaymentMethodRow
    let showsDivider: Bool
    let onTap: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(
                showsDivider: showsDivider,
                action: onTap
            ),
            leading: {
                iconView
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .padding(.leading, Layout.leadingPadding)
                    .padding(.vertical, Layout.verticalPadding)
            },
            center: {
                CellCenter(
                    primaryRow: {
                        Text(row.title)
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                    },
                    contentInsets: { insets in
                        insets.top = Layout.titleVerticalPadding
                        insets.bottom = Layout.titleVerticalPadding
                    }
                )
            },
            trailing: {
                EmptyView()
            }
        )
        .frame(height: Layout.cellHeight)
    }
}

private extension RampPaymentMethodCell {
    var iconView: some View {
        AssetAvatarView(
            imageSource: row.imageURL.map { .url($0) } ?? .image(.TKUIKit.Icons.Size28.purchase),
            configuration: Layout.iconConfiguration,
            shape: .circle,
            chainIconBackgroundColor: palette.background.content,
            imageBackgroundColor: .clear
        )
    }

    enum Layout {
        static let cellHeight: CGFloat = 56
        static let iconSize: CGFloat = 28
        static let leadingPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 14
        static let titleVerticalPadding: CGFloat = 16

        static let iconConfiguration = AssetAvatarView.Configuration(
            imageSize: iconSize,
            chainIconSize: 0,
            chainIconPadding: 0,
            chainIconOffsetX: 0,
            chainIconOffsetY: 0
        )
    }
}

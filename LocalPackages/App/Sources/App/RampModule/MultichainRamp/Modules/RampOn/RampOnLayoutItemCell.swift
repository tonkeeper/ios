import KeeperCore
import SwiftUI
import TKUIKit

struct RampOnLayoutItemCell: View {
    @Environment(\.tkPalette) private var palette
    let item: OnRampLayoutCard
    let onTap: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(
                action: onTap
            ),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(
                        imageSource: imageSource,
                        size: .small,
                        shape: .circle,
                        chainIconBackgroundColor: palette.background.contentTint,
                        imageBackgroundColor: .clear
                    )
                }
            },
            center: {
                CellCenter {
                    Text(item.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } secondaryRow: {
                    Text(item.itemDescription)
                        .textStyle(.body2)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            },
            trailing: {
                CellTrailingAccessory(
                    config: CellTrailingAccessory.Config(
                        color: .iconTertiary,
                        icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                        iconSize: 16
                    )
                )
            }
        )
    }
}

private extension RampOnLayoutItemCell {
    var imageSource: AssetAvatarViewImageSource {
        guard let url = URL(string: item.image), !item.image.isEmpty else {
            return .image(.TKUIKit.Icons.Size28.purchase)
        }
        return .url(url)
    }
}

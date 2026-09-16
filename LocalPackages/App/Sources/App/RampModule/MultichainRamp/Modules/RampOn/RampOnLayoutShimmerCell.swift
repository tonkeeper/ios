import SwiftUI
import TKUIKit

struct RampOnLayoutShimmerCell: View {
    @Environment(\.tkPalette) private var palette
    var body: some View {
        Cell(
            config: Cell.Config(
                showsDivider: false,
                action: nil
            ),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(
                        imageSource: .shimmer,
                        size: .small,
                        shape: .circle,
                        chainIconBackgroundColor: palette.background.contentTint
                    )
                }
            },
            center: {
                CellCenter(
                    primaryRow: CellCenterPrimaryRow(
                        config: .shimmer(primaryWidth: 65, secondaryWidth: 41)
                    ),
                    secondaryRow: CellCenterSecondaryRow(
                        config: .shimmer(primaryWidth: 170)
                    )
                )
            },
            trailing: {
                EmptyView()
            }
        )
    }
}

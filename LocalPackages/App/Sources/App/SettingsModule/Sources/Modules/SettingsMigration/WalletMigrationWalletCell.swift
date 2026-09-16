import SwiftUI
import TKUIKit
import UIKit

struct WalletMigrationWalletCell: View {
    let item: WalletMigrationItem
    let isSelected: Bool
    let showsDivider: Bool
    let onTap: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                showsDivider: showsDivider,
                action: onTap
            ),
            leading: {
                CellAssetLeading {
                    WalletMigrationLeadingIconView(
                        image: item.icon,
                        backgroundColor: item.iconBackgroundColor
                    )
                }
            },
            center: {
                CellCenter {
                    CellCenterPrimaryRow(
                        config: .content(
                            CellCenterPrimaryRow.Content(
                                title: item.title,
                                tags: item.tags
                            )
                        )
                    )
                } secondaryRow: {
                    CellCenterSecondaryRow(
                        config: .content(
                            CellCenterSecondaryRow.Content(
                                value: .init(
                                    title: item.subtitle
                                )
                            )
                        )
                    )
                }
            },
            trailing: {
                RadioButtonView(isSelected: isSelected)
            }
        )
    }
}

struct WalletMigrationWalletShimmerCell: View {
    let showsDivider: Bool
    @Environment(\.tkPalette) private var palette

    var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                showsDivider: showsDivider,
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
                CellCenter {
                    CellCenterPrimaryRow(
                        config: .shimmer(primaryWidth: 65, secondaryWidth: 41)
                    )
                } secondaryRow: {
                    CellCenterSecondaryRow(
                        config: .shimmer(primaryWidth: 170)
                    )
                }
            },
            trailing: {
                ShimmerSwiftUIView(
                    config: ShimmerSwiftUIView.Config(
                        color: .backgroundContentTint,
                        cornerRadius: .capsule
                    )
                )
                .frame(width: 24, height: 24)
                .padding(.trailing, 16)
            }
        )
    }
}

private struct WalletMigrationLeadingIconView: View {
    let image: UIImage
    let backgroundColor: TKColor

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(
                    width: Layout.iconContainerSize,
                    height: Layout.iconContainerSize
                )

            SwiftUI.Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white)
                .frame(
                    width: Layout.iconSize,
                    height: Layout.iconSize
                )
        }
    }
}

private enum Layout {
    static let iconContainerSize: CGFloat = 44
    static let iconSize: CGFloat = 28
}

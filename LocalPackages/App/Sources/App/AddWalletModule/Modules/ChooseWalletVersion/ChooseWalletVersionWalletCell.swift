import SwiftUI
import TKUIKit
import UIKit

struct ChooseWalletVersionWalletCell: View {
    let row: ChooseWalletVersionWalletRow
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
                    ChooseWalletVersionAvatar(isSelected: isSelected)
                }
            },
            center: {
                CellCenter {
                    CellCenterPrimaryRow(
                        config: .content(
                            .init(
                                title: row.title,
                                tags: row.tags
                            )
                        )
                    )
                } secondaryRow: {
                    CellCenterSecondaryRow(
                        config: .content(
                            .init(
                                value: .init(
                                    title: row.subtitle
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

private struct ChooseWalletVersionAvatar: View {
    @Environment(\.tkPalette) private var palette
    let isSelected: Bool

    var body: some View {
        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.ton)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(iconTintColor)
            .frame(width: Layout.iconSize, height: Layout.iconSize)
            .frame(width: Layout.containerSize, height: Layout.containerSize)
            .background(backgroundColor)
            .clipShape(Circle())
    }

    private var iconTintColor: Color {
        isSelected
            ? palette.accent.blue
            : palette.icon.secondary
    }

    private var backgroundColor: Color {
        isSelected
            ? palette.accent.blue.opacity(0.12)
            : palette.background.contentTint
    }

    enum Layout {
        static let containerSize: CGFloat = 44
        static let iconSize: CGFloat = 28
    }
}

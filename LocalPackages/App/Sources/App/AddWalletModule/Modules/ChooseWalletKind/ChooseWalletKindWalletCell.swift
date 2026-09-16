import SwiftUI
import TKUIKit
import UIKit

struct ChooseWalletKindWalletCell: View {
    let row: ChooseWalletKindRow
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
                    ChooseWalletKindAvatar(icon: row.icon)
                }
            },
            center: {
                CellCenter {
                    CellCenterPrimaryRow(
                        config: .content(
                            .init(title: row.title)
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

private struct ChooseWalletKindAvatar: View {
    @Environment(\.tkPalette) private var palette
    let icon: ChooseWalletKindIcon

    var body: some View {
        SwiftUI.Image(uiImage: iconImage)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(iconTintColor)
            .frame(width: Layout.iconSize, height: Layout.iconSize)
            .frame(width: Layout.containerSize, height: Layout.containerSize)
            .background(backgroundColor)
            .clipShape(Circle())
    }

    private var iconImage: UIImage {
        switch icon {
        case .ton:
            .TKUIKit.Icons.Size28.ton
        case .multichain:
            .TKUIKit.Icons.Size28.ellipses
        }
    }

    private var iconTintColor: Color {
        switch icon {
        case .ton:
            palette.accent.blue
        case .multichain:
            palette.accent.purple
        }
    }

    private var backgroundColor: Color {
        switch icon {
        case .ton:
            palette.accent.blue.opacity(0.12)
        case .multichain:
            palette.accent.purple.opacity(0.12)
        }
    }

    enum Layout {
        static let containerSize: CGFloat = 44
        static let iconSize: CGFloat = 28
    }
}

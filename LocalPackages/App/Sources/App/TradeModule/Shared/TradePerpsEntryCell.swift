import SwiftUI
import TKUIKit

struct TradePerpsEntryCell: View {
    let title: String
    let caption: String?
    var tags: [TKTagSwiftUIViewConfig] = []
    let action: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(action: action),
            leading: {
                CellAssetLeading {
                    ZStack {
                        Circle()
                            .fill(.accentBlue)
                            .opacity(Layout.iconBackgroundOpacity)
                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.perps)
                            .renderingMode(.template)
                            .foregroundStyle(.accentBlue)
                    }
                }
            },
            center: {
                CellCenter {
                    CellCenterPrimaryRow(
                        config: .content(
                            CellCenterPrimaryRow.Content(
                                title: title,
                                tags: tags
                            )
                        )
                    )
                } secondaryRow: {
                    if let caption {
                        CellCenterSecondaryRow(
                            config: .content(
                                CellCenterSecondaryRow.Content(
                                    value: CellCenterSecondaryRow.ValueConfig(
                                        title: caption,
                                        lineLimit: Layout.captionLineLimit
                                    )
                                )
                            )
                        )
                    }
                }
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
        .asCellsGroup(config: .init(horizontalPadding: 0))
    }
}

private extension TradePerpsEntryCell {
    enum Layout {
        static let iconBackgroundOpacity: Double = 0.12
        static let captionLineLimit = 2
        static let chevronSize: CGFloat = 16
    }
}

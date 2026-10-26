import Perps
import SwiftUI
import TKLocalize
import TKUIKit

struct TradeAssetDetailsPerpPositionSectionView: View {
    let data: TradeAssetDetailsPerpPositionViewData
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(config: .text(TKLocales.Trade.AssetDetails.PerpPosition.title))
            switch data {
            case .loading:
                AssetBalanceCell(config: .shimmer)
                    .asCellsGroup(config: .init(horizontalPadding: 0))
            case let .banner(_, title, caption):
                bannerView(title: title, caption: caption)
            case let .position(row):
                PerpsOpenPositionsCard(positions: [row], onSelect: { _ in onTap() })
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

private extension TradeAssetDetailsPerpPositionSectionView {
    func bannerView(title: String, caption: String?) -> some View {
        Cell(
            config: Cell.Config(action: onTap),
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
                                tags: [.accentTag(text: TKLocales.Common.new, accent: .accentBlue)]
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

    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let iconBackgroundOpacity: Double = 0.12
        static let captionLineLimit = 2
        static let chevronSize: CGFloat = 16
    }
}

import SwiftUI
import TKLocalize
import TKUIKit

struct TradeAssetDetailsOverviewSectionView: View {
    let screen: TradeAssetDetailsScreenViewData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(
                    TKLocales.Trade.AssetDetails.Sections.overview
                )
            )

            VStack(spacing: 0) {
                ForEach(Array(screen.overview.enumerated()), id: \.element.id) { index, metric in
                    InfoRowView(
                        title: metric.title,
                        valueText: metric.value,
                        delta: metric.secondaryValue.map { secondary in
                            InfoRowView.Delta(
                                text: secondary,
                                isPositive: metric.secondaryValuePositive
                            )
                        },
                        hintText: metric.hint
                    )
                    .padding(.horizontal, Layout.rowHorizontalPadding)
                    .overlay {
                        if index < screen.overview.count - 1 {
                            VStack {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .fill(.separatorCommon)
                                    .frame(height: TKUIKit.Constants.separatorWidth)
                                    .padding(.leading, Layout.rowHorizontalPadding)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .asCellsGroup(
                config: .init(
                    horizontalPadding: 0
                )
            )
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

private extension TradeAssetDetailsOverviewSectionView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let rowHorizontalPadding: CGFloat = 16
    }
}

import SwiftUI
import TKLocalize
import TKUIKit

struct TradeAssetDetailsTradingActivitySectionView: View {
    let tradingActivity: TradeAssetDetailsTradingActivityViewData
    let onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(
                    TKLocales.Trade.AssetDetails.Sections.tradingActivity
                )
            )

            TradingActivityView(
                leftTitle: TKLocales.Trade.AssetDetails.TradingActivity.volumeTitle,
                rightTitle: tradingActivity.volumeText,
                delta: tradingActivity.volumeChangeText.map { volumeChangeText in
                    TradingActivityView.Delta(
                        title: volumeChangeText,
                        isPositive: tradingActivity.volumeChangePositive
                    )
                },
                sellText: tradingActivity.sellText,
                buyText: tradingActivity.buyText,
                buyFraction: tradingActivity.buyFraction,
                hintText: TKLocales.Trade.AssetDetails.TradingActivity.volumeHint
            )

            Text(tradingActivity.attributionText)
                .textStyle(.body3)
                .foregroundStyle(.textTertiary)
                .tint(.accentBlue)
                .padding(.top, Layout.attributionTopPadding)
                .environment(\.openURL, OpenURLAction { url in
                    onOpenURL(url)
                    return .handled
                })
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

private extension TradeAssetDetailsTradingActivitySectionView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let attributionTopPadding: CGFloat = 12
    }
}

import SwiftUI
import TKLocalize
import TKUIKit

struct TradeAssetDetailsActionBarView: View {
    let primaryActionTitle: String
    let state: TradeAssetDetailsActionBarState
    let onBuy: () -> Void
    let onSell: () -> Void

    var body: some View {
        HStack(spacing: Layout.contentSpacing) {
            ButtonView(
                config: ButtonView.Config(
                    title: primaryActionTitle,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: onBuy
                )
            )

            if state == .buySell {
                ButtonView(
                    config: ButtonView.Config(
                        title: TKLocales.BuySellList.sell,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .primary,
                        action: onSell
                    )
                )
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.topPadding)
        .padding(.bottom, Layout.bottomPadding)
        .tkScrim(.backgroundPage, edge: .bottom)
    }
}

private extension TradeAssetDetailsActionBarView {
    enum Layout {
        static let contentSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let topPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 3
    }
}

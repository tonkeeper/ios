import SwiftUI
import TKLocalize
import TKUIKit

@available(iOS 17.0, *)
#Preview("States", traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        AssetActionButtonsRow(items: [
            AssetActionButtonsRow.Item(
                id: "send",
                icon: .TKUIKit.Icons.Size16.linkSmall,
                title: TKLocales.WalletButtons.send,
                action: {}
            ),
            AssetActionButtonsRow.Item(
                id: "receive",
                icon: .TKUIKit.Icons.Size16.qrCode,
                title: TKLocales.WalletButtons.receive,
                action: {}
            ),
            AssetActionButtonsRow.Item(
                id: "cash_buy",
                icon: .TKUIKit.Icons.Size16.dollarOutlinePlus,
                title: TKLocales.Trade.AssetDetails.Actions.cashBuy,
                action: {}
            ),
            AssetActionButtonsRow.Item(
                id: "cash_sell",
                icon: .TKUIKit.Icons.Size16.dollarOutlineMinus,
                title: TKLocales.Trade.AssetDetails.Actions.cashSell,
                action: {}
            ),
        ])
        AssetActionButtonsRow(items: [
            AssetActionButtonsRow.Item(
                id: "receive",
                icon: .TKUIKit.Icons.Size16.qrCode,
                title: TKLocales.WalletButtons.receive,
                action: {}
            ),
        ])
    }
    .padding()
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

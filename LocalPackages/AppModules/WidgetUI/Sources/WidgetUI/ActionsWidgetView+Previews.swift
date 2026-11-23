import SwiftUI
import TKLocalize
import TKUIKit
import WidgetKit

extension ActionsWidgetState {
    static func preview(swaps: Bool = true) -> Self {
        let url = URL(string: "tonkeeper://widget")
        return ActionsWidgetState(
            wallet: WidgetPreviewData.wallet,
            total: "$8 245.60",
            decimalSeparator: ".",
            hidesAmounts: false,
            actions: [
                Action(kind: .send, title: TKLocales.WalletButtons.send, url: url),
                Action(kind: .buy, title: TKLocales.WalletButtons.buyCrypto, url: url),
                Action(kind: .swap, title: TKLocales.WalletButtons.swap, url: swaps ? url : nil),
                Action(kind: .stake, title: TKLocales.WalletButtons.stake, url: url),
            ]
        )
    }
}

@available(iOS 17.0, *)
#Preview("Small", traits: .fixedLayout(width: 164, height: 164)) {
    ActionsWidgetView(state: .preview(), family: .systemSmall)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Medium", traits: .fixedLayout(width: 350, height: 164)) {
    ActionsWidgetView(state: .preview(), family: .systemMedium)
        .homeWidgetPreview()
}

@available(iOS 17.0, *)
#Preview("Medium, swap off", traits: .fixedLayout(width: 350, height: 164)) {
    ActionsWidgetView(state: .preview(swaps: false), family: .systemMedium)
        .homeWidgetPreview()
}

import SwiftUI
import TKUIKit

#Preview("Transactions") {
    BatterySupportedTransactionsView(
        networks: [
            .init(id: "ton", title: "TON", rows: [
                .init(id: "swap", title: "Swaps via Keeper", caption: "≈ 50 charges per swap"),
                .init(id: "jetton", title: "Token transfers", caption: "≈ 5 charges per transfer"),
                .init(id: "nft", title: "NFT transfers", caption: "≈ 3 charges per transfer"),
            ]),
            .init(id: "tron", title: "TRON", rows: [
                .init(id: "swap", title: "Swaps via Keeper", caption: "Depends on the swap"),
                .init(id: "trc20", title: "USD₮ TRC20 transfers", caption: "≈ 266 - 532 charges per transfer"),
            ]),
        ],
        onBack: {},
        onClose: {}
    )
    .tkPreviewTheme(.deepBlue)
}

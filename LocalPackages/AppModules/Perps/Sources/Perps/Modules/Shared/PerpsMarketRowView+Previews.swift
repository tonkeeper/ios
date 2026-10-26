import SwiftUI
import TKUIKit

@available(iOS 17.0, *)
#Preview("Market row", traits: .sizeThatFitsLayout) {
    PerpsMarketRowView(
        market: PerpsMarketRowItem(
            id: 1,
            symbol: "BTC",
            iconURL: nil,
            leverageText: "40X",
            volumeText: "$1.24B VOL",
            priceText: "$67,104.20",
            changeText: "+3.84%",
            isChangePositive: true
        )
    )
    .frame(width: 390)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

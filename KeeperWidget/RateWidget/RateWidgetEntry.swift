import SwiftUI
import TKLocalize
import WidgetKit
import WidgetUI

struct RateWidgetEntry: TimelineEntry {
    let date: Date
    let assetId: String
    /// `nil` once the app has no wallet: the asset's page needs one.
    let state: TokenWidgetState?
}

extension RateWidgetEntry {
    static let placeholder = RateWidgetEntry(
        date: Date(),
        assetId: PriceWidgetSnapshot.Asset.ton.id,
        state: TokenWidgetState(
            symbol: PriceWidgetSnapshot.Asset.ton.symbol,
            icon: nil,
            price: "$1.22",
            change: WidgetChange(text: "+1.79%", isDown: false),
            fiatChange: WidgetChange(text: "+$0.02", isDown: false),
            period: TKLocales.Widget.Period.day,
            updatedAt: Date(),
            chart: [1.18, 1.19, 1.185, 1.2, 1.195, 1.21, 1.205, 1.215, 1.22]
        )
    )

    /// The asset's page.
    func url(widget: WalletWidgetLink.Widget, family: WidgetFamily) -> URL? {
        WalletWidgetLink.Family(family).flatMap {
            WalletWidgetLink(widget: widget, family: $0, action: .open, walletId: nil, assetId: assetId).url
        }
    }
}

@available(iOS 17.0, *)
struct RateWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RateWidgetEntry
    let widget: WalletWidgetLink.Widget

    var body: some View {
        Group {
            if let state = entry.state {
                if widget == .rateChart {
                    TokenChartWidgetView(state: state, family: family)
                } else {
                    TokenWidgetView(state: state, family: family)
                }
            } else {
                WidgetMessageView(text: TKLocales.Widget.noWallet, family: family)
            }
        }
        // A tap before any wallet exists is replayed once one is added, so the message only opens the app.
        .widgetURL(entry.state == nil ? nil : entry.url(widget: widget, family: family))
        .keeperWidgetBackground()
    }
}

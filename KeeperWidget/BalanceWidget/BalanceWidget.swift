import SwiftUI
import TKLocalize
import WidgetKit
import WidgetUI

@available(iOS 17.0, *)
struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WalletWidgetLink.Widget.balance.kind,
            intent: BalanceWidgetConfigurationIntent.self,
            provider: BalanceWidgetTimelineProvider(loadsAssetIcons: true)
        ) { entry in
            BalanceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(TKLocales.Widget.Balance.title)
        .description(TKLocales.Widget.Balance.description)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
private struct BalanceWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BalanceWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, let wallet = entry.wallet {
                BalanceWidgetView(
                    state: BalanceWidgetState(
                        wallet: wallet.widgetWallet,
                        total: wallet.total,
                        totalCompact: wallet.totalCompact,
                        decimalSeparator: snapshot.decimalSeparator,
                        change: wallet.change.map { WidgetChange(text: $0.text, isDown: $0.isDown) },
                        assets: wallet.topAssets.map {
                            BalanceWidgetState.Asset(id: $0.id, symbol: $0.symbol, amount: $0.amount, icon: $0.iconURL.flatMap { entry.icons[$0] })
                        },
                        updatedAt: wallet.updatedAt,
                        hidesAmounts: snapshot.hidesAmounts
                    ),
                    family: family
                )
            } else {
                WidgetMessageView(text: entry.message, family: family)
            }
        }
        .widgetURL(entry.url(widget: .balance, family: family, action: .open))
        .keeperWidgetBackground()
    }
}

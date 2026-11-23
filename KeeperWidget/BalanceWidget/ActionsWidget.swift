import SwiftUI
import TKLocalize
import WidgetKit
import WidgetUI

/// The wallet screen's buttons, for the wallet the balance widget would show.
@available(iOS 17.0, *)
struct ActionsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WalletWidgetLink.Widget.actions.kind,
            intent: BalanceWidgetConfigurationIntent.self,
            provider: BalanceWidgetTimelineProvider()
        ) { entry in
            ActionsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(TKLocales.Widget.Actions.title)
        .description(TKLocales.Widget.Actions.description)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
private struct ActionsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BalanceWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, let wallet = entry.wallet {
                ActionsWidgetView(
                    state: ActionsWidgetState(
                        wallet: wallet.widgetWallet,
                        total: wallet.total,
                        decimalSeparator: snapshot.decimalSeparator,
                        hidesAmounts: snapshot.hidesAmounts,
                        actions: [
                            action(.send, .send, title: TKLocales.WalletButtons.send, wallet: wallet),
                            action(.buy, .buy, title: snapshot.isRampEnabled ? TKLocales.WalletButtons.buyCrypto : TKLocales.WalletButtons.deposit, wallet: wallet),
                            action(.swap, .swap, title: TKLocales.WalletButtons.swap, wallet: wallet),
                            action(.stake, .stake, title: TKLocales.WalletButtons.stake, wallet: wallet),
                        ]
                    ),
                    family: family
                )
            } else {
                WidgetMessageView(text: entry.message, family: family)
            }
        }
        .widgetURL(entry.url(widget: .actions, family: family, action: .open))
        .keeperWidgetBackground()
    }

    private func action(
        _ kind: ActionsWidgetState.Action.Kind,
        _ action: WalletWidgetLink.Action,
        title: String,
        wallet: WalletWidgetSnapshot.Wallet
    ) -> ActionsWidgetState.Action {
        ActionsWidgetState.Action(
            kind: kind,
            title: title,
            url: wallet.actions.contains(action) ? entry.url(widget: .actions, family: family, action: action) : nil
        )
    }
}

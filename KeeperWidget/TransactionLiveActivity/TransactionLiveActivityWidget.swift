import ActivityKit
import KeeperCore
import SwiftUI
import TKUIKit
import WalletExtensions
import WidgetKit

@available(iOS 16.2, *)
struct TransactionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransactionLiveActivityAttributes.self) { context in
            TransactionLiveActivityLockScreenView(
                presentation: presentation(context),
                wallet: walletLabel(context.state)
            )
            .activityBackgroundTint(TKColor.backgroundPage.resolve(TransactionLiveActivityTheme.lockScreen.palette))
            .activitySystemActionForegroundColor(
                TKColor.textPrimary.resolve(TransactionLiveActivityTheme.lockScreen.palette)
            )
            .widgetURL(link(context))
        } dynamicIsland: { context in
            let presentation = presentation(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TransactionLiveActivityExpandedLeadingView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TransactionLiveActivityExpandedBottomView(
                        presentation: presentation,
                        wallet: walletLabel(context.state)
                    )
                }
            } compactLeading: {
                TransactionLiveActivityCompactLeadingView(presentation: presentation)
            } compactTrailing: {
                TransactionLiveActivityCompactTrailingView(presentation: presentation)
            } minimal: {
                TransactionLiveActivityCompactLeadingView(presentation: presentation)
            }
            .keylineTint(presentation.tone.color.resolve(TransactionLiveActivityTheme.dynamicIsland.palette))
            .widgetURL(link(context))
        }
    }

    private func link(_ context: ActivityViewContext<TransactionLiveActivityAttributes>) -> URL? {
        let state = context.attributes.resolving(context.state)
        return TransactionLiveActivityLink(
            walletId: context.attributes.walletId,
            transactionId: state.transactionId,
            perpsMarketId: state.perpsMarketId
        ).url
    }

    private func presentation(
        _ context: ActivityViewContext<TransactionLiveActivityAttributes>
    ) -> TransactionLiveActivityPresentation {
        let counterparties = TransactionLiveActivityCounterparties.load()
        return TransactionLiveActivityPresentation(state: context.attributes.resolving(context.state), isStale: context.isStale) {
            counterparties.label(for: $0, shownWalletId: context.attributes.walletId)
        }
    }

    private func walletLabel(
        _ state: TransactionLiveActivityAttributes.ContentState
    ) -> TransactionLiveActivityWalletLabel? {
        state.wallet.map { wallet in
            TransactionLiveActivityWalletLabel(
                name: wallet.name,
                emoji: wallet.emoji,
                image: wallet.icon.flatMap(WalletIcon.Image.init(rawValue:))?.swiftUIImage
            )
        }
    }
}

import ActivityKit
import SwiftUI
import TKUIKit
import WidgetKit

@available(iOS 16.2, *)
struct TransactionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransactionLiveActivityAttributes.self) { context in
            TransactionLiveActivityLockScreenView(
                presentation: presentation(context),
                walletName: context.state.wallet?.name
            )
            .activityBackgroundTint(TKColor.backgroundPage.resolve(TransactionLiveActivityTheme.lockScreen.palette))
            .activitySystemActionForegroundColor(
                TKColor.textPrimary.resolve(TransactionLiveActivityTheme.lockScreen.palette)
            )
            .widgetURL(link(context, on: .lockScreen))
        } dynamicIsland: { context in
            let presentation = presentation(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TransactionLiveActivityExpandedLeadingView(
                        presentation: presentation,
                        walletName: context.state.wallet?.name
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TransactionLiveActivityExpandedTrailingView(presentation: presentation)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TransactionLiveActivityExpandedBottomView(presentation: presentation)
                }
            } compactLeading: {
                TransactionLiveActivityCompactLeadingView(presentation: presentation)
            } compactTrailing: {
                TransactionLiveActivityCompactTrailingView(presentation: presentation)
            } minimal: {
                TransactionLiveActivityCompactLeadingView(presentation: presentation)
            }
            .keylineTint(presentation.progress.tone.fillColor.resolve(TransactionLiveActivityTheme.dynamicIsland.palette))
            .widgetURL(link(context, on: .dynamicIsland))
        }
    }

    private func link(
        _ context: ActivityViewContext<TransactionLiveActivityAttributes>,
        on surface: TransactionLiveActivityLink.Surface
    ) -> URL? {
        let state = context.attributes.resolving(context.state)
        return TransactionLiveActivityLink(
            walletId: context.attributes.walletId,
            transactionId: state.transactionId,
            perpsMarketId: state.perpsMarketId
        ).url(on: surface)
    }

    private func presentation(
        _ context: ActivityViewContext<TransactionLiveActivityAttributes>
    ) -> TransactionLiveActivityPresentation {
        let counterparties = TransactionLiveActivityCounterparties.load()
        return TransactionLiveActivityPresentation(state: context.attributes.resolving(context.state), isStale: context.isStale) {
            counterparties.label(for: $0, shownWalletId: context.attributes.walletId)
        }
    }
}

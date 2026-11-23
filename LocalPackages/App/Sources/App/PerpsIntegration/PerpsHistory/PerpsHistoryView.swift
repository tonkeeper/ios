import AppUI
import KeeperCore
import Perps
import PerpsModels
import SwiftUI
import TKUIKit

struct PerpsHistoryView: View {
    @ObservedObject var viewModel: PerpsHistoryViewModel
    let onBack: () -> Void
    let onSelectEvent: (PerpsHistoryEvent) -> Void
    let onOpenTransaction: (URL, String?) -> Void

    @State private var selectedActivity: MultichainActivity?
    @State private var depositId: String?

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: .push(
                    title: viewModel.title,
                    backAccessibilityIdentifier: "perps_history_back_button",
                    onBack: onBack
                )
            )
            MultichainHistoryContentView(
                viewModel: viewModel.query,
                onSelectActivity: select,
                isActive: true
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .tkBottomSheet(
            item: $selectedActivity,
            header: { _, _ in .compact },
            content: { activity in
                MultichainTransactionDetailsView(
                    model: viewModel.transactionDetailsModel(for: activity),
                    onOpenTransaction: onOpenTransaction,
                    onCopy: { Pasteboard.copy(value: $0) }
                )
            }
        )
        .refreshesWhileFundingPending(selectedActivity) { [query = viewModel.query] in
            await query.refresh()
            return query.state.activities
        }
        .onReceive(viewModel.query.$state) { state in
            guard let shown = selectedActivity,
                  let current = MultichainHistoryEventTarget.current(of: shown, in: state.activities),
                  current != shown
            else { return }
            selectedActivity = current
        }
        .onChange(of: viewModel.activityToOpen) { activity in
            guard let activity else { return }
            select(activity)
            viewModel.didOpenFocusedActivity()
        }
        .onDisappear {
            viewModel.query.disappeared()
        }
        .tkBottomSheet(item: $depositId, header: { _, _ in .depositStatusContent }) { id in
            if let model = viewModel.depositStatus {
                PerpsDepositStatusDetailsView(model: model, depositId: id) { depositId = nil }
            }
        }
    }

    private func select(_ activity: MultichainActivity) {
        if let deposit = viewModel.trackedDeposit(matching: activity), let model = viewModel.depositStatus {
            depositId = deposit.id
            model.didOpen(deposit.id)
        } else if let event = viewModel.historyEvents.event(from: activity) {
            onSelectEvent(event)
        } else {
            viewModel.showsFundingStatus = activity.status == .pending
            selectedActivity = activity
        }
    }
}

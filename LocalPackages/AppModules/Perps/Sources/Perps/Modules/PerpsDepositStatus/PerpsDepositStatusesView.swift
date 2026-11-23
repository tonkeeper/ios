import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsDepositStatusesView: View {
    @ObservedObject var model: PerpsDepositStatusViewModel
    let onClose: () -> Void
    @State private var selection: PerpsDepositStatusSelection?
    @State private var hidden: Set<String>?

    private var listed: [PerpsDepositStatus] {
        model.deposits.filter { $0.state == .pending || hidden?.contains($0.id) != true }
    }

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(config: .init(title: .init(text: TKLocales.Perps.DepositStatus.statuses), rightIcon: .close { _ in onClose() }))
            VStack(spacing: 0) {
                ForEach(listed) { deposit in
                    let amount = model.listedAmount(deposit)
                    let problem = problemText(deposit)
                    TransactionCell(
                        config: .content(.init(
                            icon: .init(
                                image: problem == nil
                                    ? .TKUIKit.Icons.Size28.trayArrowDown
                                    : .TKUIKit.Icons.Size28.exclamationmarkCircle,
                                tint: problem == nil ? .iconSecondary : .accentOrange,
                                badge: deposit.state == .pending ? .loader : nil
                            ),
                            title: title(deposit),
                            subtitle: .init(text: TKLocales.Perps.balance, style: .primary),
                            amount: .init(title: amount.text, style: amount.positive ? .positive : .primary),
                            accessory: .init(text: model.format.candleDateTime(deposit.createdAt)),
                            details: problem.map { .init(title: .init(text: $0, color: .accentOrange)) },
                            showsDivider: deposit.id != listed.last?.id
                        )),
                        onTap: {
                            selection = .init(id: deposit.id)
                            model.didOpen(deposit.id)
                        }
                    )
                }
            }
            .background(.backgroundContent)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.backgroundPage)
        .onAppear {
            let seen = model.didOpenList()
            if hidden == nil { hidden = seen }
        }
        .onDisappear { model.didCloseList() }
        .tkBottomSheet(item: $selection, header: { _, _ in .depositStatusContent }) { selection in
            PerpsDepositStatusDetailsView(model: model, depositId: selection.id) { self.selection = nil }
        }
    }

    private func title(_ deposit: PerpsDepositStatus) -> String {
        switch deposit.state {
        case .pending: TKLocales.Perps.DepositStatus.depositing
        case .completed: TKLocales.Perps.DepositStatus.deposited
        case .failed, .refunded, .unconfirmed: TKLocales.Perps.deposit
        }
    }

    private func problemText(_ deposit: PerpsDepositStatus) -> String? {
        switch deposit.state {
        case .failed, .refunded: TKLocales.State.failed
        case .unconfirmed: TKLocales.Perps.DepositStatus.unconfirmed
        case .pending, .completed: nil
        }
    }
}

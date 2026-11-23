import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit

public struct PerpsDepositStatusDetailsView: View {
    @ObservedObject private var model: PerpsDepositStatusViewModel
    private let depositId: String
    private let onClose: () -> Void
    @State private var showsHelp = false
    @State private var shownDepositId: String?

    public init(model: PerpsDepositStatusViewModel, depositId: String, onClose: @escaping () -> Void) {
        self.model = model
        self.depositId = depositId
        self.onClose = onClose
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let deposit = model.deposit(depositId) {
                VStack(spacing: 0) {
                    DefaultModalCardHeader(config: .init(
                        leftIcon: .init(image: .TKUIKit.Icons.Size28.question, size: 16, padding: 8, onTap: { _ in showsHelp = true }),
                        title: .init(text: TKLocales.Perps.DepositStatus.title),
                        subtitle: subtitle(deposit, at: context.date).map { .init(text: $0) },
                        rightIcon: .close { _ in onClose() }
                    ))
                    VStack(spacing: 8) {
                        steps(deposit, at: context.date)
                        if deposit.isDelayed(at: context.date) {
                            Text(TKLocales.Perps.DepositStatus.safeFunds)
                                .textStyle(.body2)
                                .foregroundStyle(.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                        }
                        details(deposit)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(.backgroundPage)
                .onAppear { shownDepositId = depositId }
                .onChange(of: depositId) { shownDepositId = $0 }
            } else {
                // The journal can drop the record while the sheet is open: a settled one ages out after a day.
                // A record the model has not picked up yet is not gone.
                Color.clear.onAppear { if shownDepositId == depositId { onClose() } }
            }
        }
        .alert(TKLocales.Perps.DepositStatus.title, isPresented: $showsHelp) {
            Button(TKLocales.Actions.ok, role: .cancel) {}
        } message: {
            Text(TKLocales.Perps.DepositStatus.help)
        }
    }

    private func subtitle(_ deposit: PerpsDepositStatus, at date: Date) -> String? {
        switch deposit.state {
        case .completed: TKLocales.Perps.DepositStatus.sheetCompleted
        case .failed: TKLocales.State.failed
        case .refunded: TKLocales.Perps.DepositStatus.refunded
        case .unconfirmed: TKLocales.Perps.DepositStatus.unconfirmed
        case .pending: deposit.isDelayed(at: date) ? TKLocales.Perps.DepositStatus.delayed : model.duration(deposit)
        }
    }

    private func steps(_ deposit: PerpsDepositStatus, at date: Date) -> some View {
        VStack(spacing: 0) {
            if deposit.step == nil, deposit.state != .completed {
                stepRow(
                    title: deposit.state == .pending ? TKLocales.Perps.DepositStatus.inProgress : subtitle(deposit, at: .distantPast) ?? TKLocales.Perps.DepositStatus.inProgress,
                    subtitle: sent(deposit),
                    state: deposit.state == .pending ? .current : .failed,
                    isRefunded: deposit.state == .refunded
                )
            } else {
                let indices = deposit.skipsConversion ? [0, 2] : [0, 1, 2]
                ForEach(indices, id: \.self) { index in
                    stepRow(
                        title: title(index, deposit: deposit),
                        subtitle: caption(index, deposit: deposit, at: date),
                        state: state(index, deposit: deposit),
                        isRefunded: deposit.state == .refunded
                    )
                    .overlay(alignment: .bottomLeading) {
                        if index != indices.last {
                            let done = state(index, deposit: deposit) == .done
                            Rectangle()
                                .fill(done ? TKColor.accentGreen.opacity(0.32) : TKColor.backgroundContentTint)
                                .frame(width: 2, height: 24)
                                .offset(x: 37, y: 12)
                        }
                    }
                }
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private enum StepState { case waiting, current, done, failed }

    private func state(_ index: Int, deposit: PerpsDepositStatus) -> StepState {
        if deposit.state == .completed { return .done }
        guard let step = deposit.step else { return .waiting }
        if index < step.rawValue { return .done }
        if index > step.rawValue { return .waiting }
        return deposit.state == .pending ? .current : .failed
    }

    private func stepRow(title: String, subtitle: String, state: StepState, isRefunded: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(state == .waiting ? TKColor.buttonTertiaryBackgroundDisabled : TKColor.backgroundContentTint)
                if state == .done {
                    Circle().fill(TKColor.accentGreen.opacity(0.12))
                    Image(uiImage: .TKUIKit.Icons.Size32.checkmarkCircle)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.accentGreen)
                } else if state == .failed {
                    Circle().fill(TKColor.accentOrange.opacity(0.12))
                    Image(uiImage: isRefunded ? .TKUIKit.Icons.Size28.returnArrow : .TKUIKit.Icons.Size28.exclamationmarkCircle)
                        .foregroundStyle(.accentOrange)
                } else if state == .current {
                    CircularLoader(mode: .indeterminate, preset: .medium)
                }
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .textStyle(.label1)
                    .foregroundStyle(state == .waiting ? TKColor.textSecondary : .textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(captionColor(state))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(minHeight: 76)
    }

    private func captionColor(_ state: StepState) -> TKColor {
        switch state {
        case .failed: .accentOrange
        case .waiting: .textTertiary
        case .current, .done: .textSecondary
        }
    }

    private func title(_ index: Int, deposit: PerpsDepositStatus) -> String {
        if state(index, deposit: deposit) == .failed {
            switch index {
            case 0: return TKLocales.Perps.DepositStatus.couldntSend
            case 1: return deposit.isUSDC ? TKLocales.Perps.DepositStatus.couldntTransfer : TKLocales.Perps.DepositStatus.couldntConvert
            default: return TKLocales.Perps.DepositStatus.couldntAdd
            }
        }
        switch index {
        case 0: return TKLocales.Perps.DepositStatus.sending
        case 1:
            let done = state(index, deposit: deposit) == .done
            if deposit.isUSDC {
                return done ? TKLocales.Perps.DepositStatus.transferred : TKLocales.Perps.DepositStatus.transferring
            }
            return done ? TKLocales.Perps.DepositStatus.converted : TKLocales.Perps.DepositStatus.converting
        default: return state(index, deposit: deposit) == .done ? TKLocales.Perps.DepositStatus.confirmed : TKLocales.Perps.DepositStatus.adding
        }
    }

    private func caption(_ index: Int, deposit: PerpsDepositStatus, at date: Date) -> String {
        if state(index, deposit: deposit) == .failed {
            return deposit.state == .refunded ? TKLocales.Perps.DepositStatus.returned(model.amount(deposit)) : TKLocales.State.failed
        }
        switch index {
        case 0: return sent(deposit)
        case 1: return TKLocales.Perps.DepositStatus.conversion(deposit.sourceSymbol)
        default:
            let value = approximate(model.received(deposit))
            return deposit.isDelayed(at: date) ? value + " USDC" : value
        }
    }

    private func details(_ deposit: PerpsDepositStatus) -> some View {
        VStack(spacing: 0) {
            detail(TKLocales.MultichainSwap.Details.youSend, model.amount(deposit) + " · " + networkName(deposit))
            detail(TKLocales.Perps.DepositStatus.youGet, approximate(model.received(deposit)))
            detail(TKLocales.EventDetails.protocol, "Lighter")
        }
        .padding(.vertical, 4)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label).foregroundStyle(.textSecondary)
            Spacer(minLength: 0)
            Text(value).foregroundStyle(.textPrimary).multilineTextAlignment(.trailing)
        }
        .textStyle(.body2)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func sent(_ deposit: PerpsDepositStatus) -> String {
        model.amount(deposit) + " · " + TKLocales.Perps.DepositStatus.network(networkName(deposit))
    }

    private func approximate(_ value: String) -> String {
        model.format.hiddenBalanceText == nil ? TKLocales.Perps.DepositStatus.approximateAmount(value) : value
    }

    private func networkName(_ deposit: PerpsDepositStatus) -> String {
        PerpsFundingNetwork(chainPrefix: deposit.sourceNetwork)?.displayName ?? deposit.sourceNetwork.uppercased()
    }
}

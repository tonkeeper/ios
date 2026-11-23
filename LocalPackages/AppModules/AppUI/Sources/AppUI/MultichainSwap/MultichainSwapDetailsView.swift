import SwiftUI
import TKLocalize
import TKUIKit

public struct MultichainSwapDetailsView: View {
    @Environment(\.tkPalette) private var palette

    let state: MultichainSwapDetailsViewState
    let onClose: () -> Void
    let onOpenTransaction: (URL, String?) -> Void
    let onCopyTransactionHash: (String) -> Void

    public init(
        state: MultichainSwapDetailsViewState,
        onClose: @escaping () -> Void,
        onOpenTransaction: @escaping (URL, String?) -> Void,
        onCopyTransactionHash: @escaping (String) -> Void
    ) {
        self.state = state
        self.onClose = onClose
        self.onOpenTransaction = onOpenTransaction
        self.onCopyTransactionHash = onCopyTransactionHash
    }

    public var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: .init(
                    title: .init(text: TKLocales.MultichainSwap.Details.title),
                    rightIcon: .close { _ in onClose() }
                )
            )
            VStack(spacing: Layout.spacing) {
                VStack(spacing: Layout.spacing) {
                    amountCard(caption: TKLocales.MultichainSwap.Details.youSend, amount: state.send)
                    amountCard(caption: TKLocales.MultichainSwap.Details.youReceive, amount: state.receive)
                }
                .overlay(alignment: .trailing) {
                    directionBadge
                        .padding(.trailing, Layout.directionBadgeTrailingPadding)
                }
                VStack(spacing: 0) {
                    MultichainSwapConfirmationDetailRow(
                        title: TKLocales.MultichainSwap.Details.date,
                        value: state.date
                    )
                    if let networkFee = state.networkFee {
                        MultichainSwapConfirmationDetailRow(
                            title: TKLocales.FeeMethodPicker.title,
                            value: networkFee
                        )
                    }
                    MultichainSwapConfirmationDetailRow(
                        title: TKLocales.MultichainSwap.Details.status,
                        value: statusText,
                        valueColor: statusColor,
                        trailingAccessory: statusAccessory,
                        showsDivider: false
                    )
                }
                .background(.backgroundContent)
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
                transactions
                    .padding(.top, Layout.transactionsTopPadding)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension MultichainSwapDetailsView {
    func amountCard(caption: String, amount: MultichainSwapDetailsViewState.Amount) -> some View {
        HStack(spacing: Layout.cardSpacing) {
            AssetAvatarView(imageSource: amount.avatarSource, size: .small)
            VStack(alignment: .leading, spacing: 0) {
                Text(caption)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                Text(amount.value)
                    .textStyle(.num2)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(Layout.cardInsets)
        .background(.buttonSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous))
    }

    var directionBadge: some View {
        SwiftUI.Image.TKUIKit.Icons.Size16.arrowDown
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundStyle(.buttonTertiaryForeground)
            .frame(width: Layout.directionBadgeSide, height: Layout.directionBadgeSide)
            .background(Circle().fill(.buttonTertiaryBackground))
    }

    /// Two transactions that do not fit side by side, as in longer locales, go one under the other.
    @ViewBuilder
    var transactions: some View {
        if #available(iOS 16.0, *) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Layout.spacing) { transactionChips }
                VStack(spacing: Layout.spacing) { transactionChips }
            }
        } else {
            VStack(spacing: Layout.spacing) { transactionChips }
        }
    }

    var transactionChips: some View {
        ForEach(Array(state.transactions.enumerated()), id: \.offset) { _, transaction in
            switch transaction {
            case let .link(button, hash):
                ButtonView(
                    config: ButtonView.Config(
                        title: button.title.resolve(palette),
                        size: .small,
                        appearance: .secondary,
                        icon: ButtonView.Icon(
                            image: .TKUIKit.Icons.Size16.globe,
                            alignment: .leading
                        ),
                        action: {}
                    )
                )
                .simultaneousGesture(
                    TapGesture()
                        .exclusively(before: LongPressGesture())
                        .onEnded { value in
                            switch value {
                            case .first:
                                onOpenTransaction(button.url, button.browserTitle)
                            case .second:
                                onCopyTransactionHash(hash)
                            }
                        }
                )
                .accessibilityAction {
                    onOpenTransaction(button.url, button.browserTitle)
                }
                .accessibilityAction(named: Text(TKLocales.Actions.copy)) {
                    onCopyTransactionHash(hash)
                }
            case .receiving:
                receivingChip
            }
        }
    }

    var receivingChip: some View {
        HStack(spacing: Layout.spacing) {
            CircularLoader(mode: .indeterminate, preset: .small)
            Text(TKLocales.ActionTypes.receiving)
                .textStyle(.label2)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Layout.chipHorizontalPadding)
        .frame(height: Layout.chipHeight)
        .background(Capsule().fill(.buttonSecondaryBackground))
    }

    var statusText: String {
        switch state.status {
        case .pending: TKLocales.MultichainSwap.Details.pending
        case .done: TKLocales.Result.success
        case .failed: TKLocales.State.failed
        }
    }

    var statusColor: TKColor {
        switch state.status {
        case .pending: .textSecondary
        case .done: .accentGreen
        case .failed: .accentOrange
        }
    }

    var statusAccessory: AnyView? {
        guard state.status == .pending else { return nil }
        return AnyView(
            CircularLoader(mode: .indeterminate, preset: .small)
                .padding(.leading, Layout.statusLoaderLeadingPadding)
        )
    }

    enum Layout {
        static let spacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 16
        static let cardSpacing: CGFloat = 12
        static let cardInsets = EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16)
        static let directionBadgeSide: CGFloat = 40
        static let directionBadgeTrailingPadding: CGFloat = 28
        static let transactionsTopPadding: CGFloat = 24
        static let chipHeight: CGFloat = 36
        static let chipHorizontalPadding: CGFloat = 16
        /// Together with the row's own spacing it keeps the loader 8 pt from the status.
        static let statusLoaderLeadingPadding: CGFloat = 4
    }
}

import SwiftUI
import TKLocalize
import TKUIKit

/// The Perps title, or the withdrawal pill in its place while there is one.
struct PerpsRootHeaderTitle<Title: View>: View {
    @ObservedObject var status: PerpsWithdrawStatusViewModel
    @ViewBuilder let title: () -> Title

    var body: some View {
        if let current = status.status {
            PerpsWithdrawStatusPill(status: current) { status.tap() }
                .transition(.opacity)
        } else {
            title()
                .transition(.opacity)
        }
    }
}

struct PerpsWithdrawStatusPill: View {
    let status: PerpsWithdrawStatusViewModel.Status
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: isSent ? Layout.sentSpacing : Layout.spacing) {
                icon
                if isSent {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(TKLocales.Perps.WithdrawStatus.sent)
                            .textStyle(.label2)
                            .foregroundStyle(.textPrimary)
                        Text(TKLocales.Perps.WithdrawStatus.checkHistory)
                            .textStyle(.body3)
                            .foregroundStyle(.textSecondary)
                    }
                    .lineLimit(1)
                    Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                        .renderingMode(.template)
                        .foregroundStyle(.iconSecondary)
                } else {
                    Text(title)
                        .textStyle(.label2)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, Layout.leadingPadding)
            .padding(.trailing, isSent ? Layout.sentTrailingPadding : Layout.trailingPadding)
            .frame(minHeight: Layout.height)
            .background(Capsule().fill(.backgroundContentTint))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("perps_withdraw_status")
    }

    private var isSent: Bool {
        if case .sent = status { return true }
        return false
    }

    private var title: String {
        switch status {
        case .sending: TKLocales.Perps.WithdrawStatus.sending
        case .sent: TKLocales.Perps.WithdrawStatus.sent
        case .confirmed: TKLocales.Perps.WithdrawStatus.confirmed
        case .failed: TKLocales.Perps.WithdrawStatus.failed
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch status {
        case .sending:
            CircularLoader(mode: .indeterminate, preset: .small)
        case .sent:
            Image(uiImage: .TKUIKit.Icons.Size28.clockOutline)
                .resizable()
                .renderingMode(.template)
                .frame(width: Layout.iconSide, height: Layout.iconSide)
                .foregroundStyle(.iconSecondary)
        case .confirmed:
            Image(uiImage: .TKUIKit.Icons.Size16.checkmarkCircle)
                .renderingMode(.template)
                .foregroundStyle(.accentGreen)
        case .failed:
            Image(uiImage: .TKUIKit.Icons.Size16.xmarkCircle)
                .renderingMode(.template)
                .foregroundStyle(.accentRed)
        }
    }
}

private enum Layout {
    static let height: CGFloat = 40
    static let iconSide: CGFloat = 16
    static let spacing: CGFloat = 8
    static let sentSpacing: CGFloat = 10
    static let leadingPadding: CGFloat = 16
    static let trailingPadding: CGFloat = 20
    static let sentTrailingPadding: CGFloat = 12
}

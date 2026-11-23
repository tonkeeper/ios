import SwiftUI
import TKLocalize
import TKUIKit

/// The accounts of a Ledger at multichain pairing, each with its addresses in the networks the Ledger's apps reached.
/// The user picks the ones to add, reads more of them a page at a time, or reads one by its number.
public struct LedgerAccountsScreen: View {
    private let state: LedgerAccountsScreenState
    private let headerIcon: DefaultModalCardHeader.Icon?
    private let onToggle: (Int) -> Void
    private let onShowMore: () -> Void
    private let onAddByNumber: () -> Void
    private let onContinue: () -> Void

    public init(
        state: LedgerAccountsScreenState,
        headerIcon: DefaultModalCardHeader.Icon?,
        onToggle: @escaping (Int) -> Void,
        onShowMore: @escaping () -> Void,
        onAddByNumber: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.state = state
        self.headerIcon = headerIcon
        self.onToggle = onToggle
        self.onShowMore = onShowMore
        self.onAddByNumber = onAddByNumber
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(config: DefaultModalCardHeader.Config(leftIcon: headerIcon, height: .compact))
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    title
                    if !state.accounts.isEmpty {
                        accounts
                    }
                    if state.isReading {
                        CircularLoader(mode: .indeterminate, preset: .medium)
                            .padding(.vertical, Layout.loaderInset)
                    } else {
                        actions
                    }
                }
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.bottom, Layout.horizontalInset)
            }

            ButtonView(
                config: ButtonView.Config(
                    title: TKLocales.Actions.continueAction,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: onContinue
                )
            )
            .disabled(!state.isContinueEnabled)
            .padding(.horizontal, Layout.horizontalInset)
            .padding(.bottom, Layout.buttonBottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension LedgerAccountsScreen {
    var title: some View {
        VStack(spacing: Layout.titleSpacing) {
            Text(TKLocales.LedgerAccounts.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
            Text(TKLocales.LedgerAccounts.description)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.titleHorizontalInset)
    }

    var accounts: some View {
        card {
            ForEach(state.accounts) { account in
                if account.id != state.accounts.first?.id {
                    separator
                }
                LedgerAccountRow(account: account) {
                    onToggle(account.id)
                }
            }
        }
    }

    var actions: some View {
        card {
            if state.canShowMore {
                actionRow(TKLocales.LedgerAccounts.showMore, action: onShowMore)
                separator
            }
            actionRow(TKLocales.LedgerAccounts.addByNumber, action: onAddByNumber)
        }
    }

    func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
    }

    func actionRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .textStyle(.label1)
                .foregroundStyle(.accentBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Layout.rowInset)
                .contentShape(Rectangle())
        }
        .buttonStyle(TKTapAnimationButtonStyle())
    }

    var separator: some View {
        Rectangle()
            .fill(.separatorCommon)
            .frame(height: Layout.separatorHeight)
            .padding(.leading, Layout.rowInset)
    }
}

private struct LedgerAccountRow: View {
    let account: LedgerAccountsScreenState.Account
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: Layout.addressSpacing) {
                HStack(spacing: Layout.tagSpacing) {
                    Text(account.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                    if account.isAdded {
                        TKTagSwiftUIView(config: .tag(text: TKLocales.ChooseWallets.alreadyAdded))
                    }
                    Spacer(minLength: 0)
                    if !account.isAdded {
                        CheckboxView(isSelected: account.isSelected)
                    }
                }
                .frame(minHeight: Layout.titleHeight)
                .padding(.bottom, Layout.titleBottomInset)
                ForEach(account.addresses) { address in
                    HStack(spacing: Layout.rowSpacing) {
                        Text(address.network)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                        Spacer(minLength: 0)
                        Text(address.value)
                            .textStyle(.body2)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(Layout.rowInset)
            .contentShape(Rectangle())
        }
        .buttonStyle(TKTapAnimationButtonStyle())
        .disabled(account.isAdded)
    }
}

private enum Layout {
    static let horizontalInset: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let titleSpacing: CGFloat = 4
    static let titleHorizontalInset: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let rowInset: CGFloat = 16
    static let rowSpacing: CGFloat = 12
    static let addressSpacing: CGFloat = 2
    static let tagSpacing: CGFloat = 6
    static let titleHeight: CGFloat = 28
    static let titleBottomInset: CGFloat = 2
    static let separatorHeight: CGFloat = 0.5
    static let buttonBottomInset: CGFloat = 16
    static let loaderInset: CGFloat = 16
}

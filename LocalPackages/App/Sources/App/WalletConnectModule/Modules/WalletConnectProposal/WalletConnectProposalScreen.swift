import SwiftUI
import TKLocalize
import TKUIKit

struct WalletConnectProposalScreen: View {
    @ObservedObject var viewModel: WalletConnectProposalViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            proposalContent
            actionBar
        }
        .background(.backgroundPage)
    }
}

private extension WalletConnectProposalScreen {
    var proposalContent: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    WalletConnectProposalHeroView(
                        content: viewModel.content,
                        onDAppHostTap: viewModel.openDAppHost
                    )
                    walletCell
                    permissionsSection
                    networksSection
                }
                .padding(.bottom, Layout.scrollBottomPadding)
            }
            .tkImmediateButtonPresses()
        }
    }

    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                title: .empty,
                rightIcon: viewModel.canReject
                    ? .close(
                        onTap: { _ in
                            viewModel.reject()
                        }
                    )
                    : nil,
                height: .atLeast(Layout.headerHeight)
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    var walletCell: some View {
        WalletConnectBalanceCell(
            content: WalletConnectBalanceCellContent(
                title: viewModel.content.walletTitle,
                balance: viewModel.content.walletBalance
            ),
            action: {
                viewModel.tapWalletPicker()
            }
        )
        .asCellsGroup()
        .padding(.bottom, Layout.walletBottomPadding)
    }

    var permissionsSection: some View {
        VStack(spacing: 0) {
            permissionsTitle
            permissionsList
        }
        .padding(.bottom, Layout.permissionsBottomPadding)
    }

    var permissionsTitle: some View {
        ListTitleView(config: .text(TKLocales.WalletConnect.Proposal.Permissions.title))
            .padding(.horizontal, Layout.horizontalPadding)
    }

    var permissionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.content.permissions.enumerated()), id: \.element.id) { _, item in
                WalletConnectPermissionCell(
                    content: WalletConnectPermissionCellContent(title: item.title)
                )
            }
        }
        .padding(.vertical, 12)
        .asCellsGroup()
    }

    @ViewBuilder
    var networksSection: some View {
        if !viewModel.content.chains.isEmpty {
            networksTitle

            if viewModel.content.chains.count == 1 {
                networksList
            } else {
                networksSummary
            }
        }
    }

    var networksTitle: some View {
        ListTitleView(config: .text(TKLocales.WalletConnect.Proposal.networks))
            .padding(.horizontal, Layout.horizontalPadding)
    }

    var networksList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.content.chains.enumerated()), id: \.element.id) { index, item in
                WalletConnectChainCell(
                    content: item.cellContent,
                    showsDivider: index < viewModel.content.chains.count - 1
                )
            }
        }
        .asCellsGroup()
    }

    var networksSummary: some View {
        WalletConnectNetworksSummaryCell(
            content: WalletConnectNetworksSummaryCellContent(
                icons: viewModel.content.chains.map(\.cellContent.icon)
            ),
            action: {
                viewModel.tapNetworksList()
            }
        )
        .asCellsGroup()
    }

    var actionBar: some View {
        VStack(spacing: 0) {
            ZStack {
                ButtonView(
                    config: ButtonView.Config(
                        title: TKLocales.WalletConnect.Proposal.connectWallet,
                        size: .large,
                        layoutMode: .fill,
                        appearance: viewModel.content.validation.proposalActionButtonAppearance,
                        action: {
                            viewModel.approve()
                        }
                    )
                )
                .opacity(viewModel.actionBarState == .idle && viewModel.canApprove ? 1 : 0)
                .disabled(viewModel.actionBarState != .idle || !viewModel.canApprove)

                actionBarOverlay
            }
            .padding(Layout.actionButtonPadding)

            Text(viewModel.content.validation.proposalActionDescription)
                .textStyle(.body2)
                .foregroundStyle(viewModel.content.validation.proposalActionDescriptionColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.actionDescriptionHorizontalPadding)
                .padding(.bottom, Layout.actionDescriptionBottomPadding)
        }
        .background(.backgroundPage.opacity(0.96), ignoresSafeAreaEdges: .bottom)
    }

    @ViewBuilder
    var actionBarOverlay: some View {
        switch viewModel.actionBarState {
        case .idle:
            EmptyView()
        case .loading:
            CircularLoader(
                mode: .indeterminate,
                preset: .medium
            )
        case .success:
            WalletConnectProposalActionResultView(state: .success)
        case .failure:
            WalletConnectProposalActionResultView(state: .failure)
        }
    }

    enum Layout {
        static let headerHeight: CGFloat = 64
        static let horizontalPadding: CGFloat = 16
        static let walletBottomPadding: CGFloat = 16
        static let permissionsBottomPadding: CGFloat = 12
        static let scrollBottomPadding: CGFloat = 165
        static let actionButtonPadding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        static let actionDescriptionHorizontalPadding: CGFloat = 32
        static let actionDescriptionBottomPadding: CGFloat = 3
    }
}

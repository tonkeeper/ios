import SwiftUI
import TKLocalize
import TKUIKit

struct WalletMigrationScreen: View {
    @ObservedObject var viewModel: WalletMigrationViewModel
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                optionalHeader

                switch viewModel.state {
                case .loading:
                    ScrollView(showsIndicators: false) {
                        walletsShimmerList
                    }
                    .tkImmediateButtonPresses()
                case .empty:
                    emptyStateView
                case .failed:
                    errorStateView
                case .wallets:
                    ScrollView(showsIndicators: false) {
                        walletsList
                    }
                    .tkImmediateButtonPresses()
                }
            }

            if showsActionBar {
                actionBar
            }
        }
        .background(.backgroundPage)
        .task {
            await viewModel.start()
        }
        .onAppear {
            viewModel.screenAppeared()
        }
        .onDisappear {
            viewModel.screenDisappeared()
        }
    }
}

private extension WalletMigrationScreen {
    var showsActionBar: Bool {
        switch viewModel.state {
        case .loading, .wallets:
            true
        case .empty, .failed:
            false
        }
    }

    @ViewBuilder
    var optionalHeader: some View {
        switch viewModel.state {
        case .empty:
            EmptyView()
        default:
            header
        }
    }

    var header: some View {
        VStack(spacing: 0) {
            VStack(spacing: Layout.headerSpacing) {
                Text(TKLocales.Settings.Migration.title)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(TKLocales.Settings.Migration.description)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            howItWorksButton
                .padding(.top, Layout.howItWorksTopPadding)
        }
        .padding(.top, Layout.headerTopPadding)
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .padding(.bottom, Layout.headerBottomPadding)
    }

    var howItWorksButton: some View {
        Button {
            viewModel.howItWorksTapped()
        } label: {
            HStack(spacing: Layout.howItWorksSpacing) {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.informationCircle)
                    .renderingMode(.template)

                Text(TKLocales.Settings.Migration.howItWorks)
                    .textStyle(.body1)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.accentBlue)
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
    }

    var walletsShimmerList: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< Layout.shimmerRowsCount, id: \.self) { index in
                WalletMigrationWalletShimmerCell(
                    showsDivider: index < Layout.shimmerRowsCount - 1
                )
            }
        }
        .asCellsGroup()
        .padding(.bottom, Layout.scrollBottomPadding)
    }

    var walletsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                WalletMigrationWalletCell(
                    item: item,
                    isSelected: viewModel.selectedWalletId == item.id,
                    showsDivider: index < viewModel.items.count - 1,
                    onTap: {
                        viewModel.selectWallet(id: item.id)
                    }
                )
            }
        }
        .asCellsGroup()
        .padding(.bottom, Layout.scrollBottomPadding)
    }

    var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            PlaceholderView(
                config: PlaceholderView.Config(
                    image: .TKUIKit.Icons.Size28.trayArrowDown,
                    title: TKLocales.Settings.Migration.Empty.title,
                    subtitle: TKLocales.Settings.Migration.Empty.subtitle,
                    button: PlaceholderView.ButtonConfig(
                        title: TKLocales.Settings.Migration.Empty.addWallet,
                        action: viewModel.addTonWalletTapped
                    )
                )
            )
            .padding(.horizontal, Layout.headerHorizontalPadding)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var errorStateView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            PlaceholderView(
                config: PlaceholderView.Config(
                    lottieResource: .exclamationmarkCircle,
                    title: TKLocales.Trade.Placeholder.errorTitle,
                    subtitle: TKLocales.Trade.Placeholder.errorSubtitle,
                    button: PlaceholderView.ButtonConfig(
                        title: TKLocales.Actions.retry,
                        icon: .TKUIKit.Icons.Size16.refresh,
                        action: {
                            Task {
                                await viewModel.retry()
                            }
                        }
                    )
                )
            )
            .padding(.horizontal, Layout.headerHorizontalPadding)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var actionBar: some View {
        ButtonView(
            config: ButtonView.Config(
                title: TKLocales.Actions.continueAction,
                size: .large,
                layoutMode: .fill,
                appearance: .primary,
                action: viewModel.continueTapped
            )
        )
        .disabled(!viewModel.isContinueEnabled)
        .padding(Layout.actionButtonPadding)
        .background(.backgroundPage.opacity(0.96), ignoresSafeAreaEdges: .bottom)
    }

    enum Layout {
        static let headerTopPadding: CGFloat = 23
        static let headerSpacing: CGFloat = 3
        static let headerHorizontalPadding: CGFloat = 32
        static let headerBottomPadding: CGFloat = 29
        static let howItWorksTopPadding: CGFloat = 8
        static let howItWorksSpacing: CGFloat = 8
        static let scrollBottomPadding: CGFloat = 96
        static let shimmerRowsCount = 5
        static let actionButtonPadding = EdgeInsets(top: 16, leading: 32, bottom: 32, trailing: 32)
    }
}

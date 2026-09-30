import LocalAuthentication
import SwiftUI
import TKLocalize
import TKUIKit

struct MultichainWalletRootView: View {
    @ObservedObject var viewModel: MultichainWalletRootViewModel

    var body: some View {
        MultichainWalletContentView(
            rootViewModel: viewModel,
            viewModel: viewModel.walletViewModel
        )
    }
}

private struct MultichainWalletContentView: View {
    @ObservedObject var rootViewModel: MultichainWalletRootViewModel
    @ObservedObject var viewModel: MultichainWalletViewModel
    @Environment(\.tkPalette) private var palette

    @State private var settledWalletId: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                MultichainWalletBalanceSection(
                    viewModel: viewModel.balanceViewModel,
                    showsShimmer: showsSkeleton
                )

                MultichainWalletIconButtonsSection(
                    config: iconButtonsConfig,
                    onSend: viewModel.tapSend,
                    onDeposit: viewModel.tapDeposit,
                    onSwap: viewModel.tapSwap,
                    onStake: viewModel.tapStake
                )

                MultichainWalletHomeBannersSection(
                    viewModel: viewModel.homeBannersViewModel,
                    showsShimmer: showsSkeleton
                )
                .id(viewModel.homeBannersViewModel.wallet.id)

                if !showsSkeleton,
                   let raffle = rootViewModel.rafflePresentation,
                   raffle.shouldShowMainScreenEntry
                {
                    RaffleEntryPointView(
                        title: raffle.compactTitle,
                        ticketsText: raffle.ticketsText,
                        action: rootViewModel.tapRaffle
                    )
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .onAppear {
                        rootViewModel.raffleBannerDidAppear()
                    }
                }

                if case let .visible(items, isSkippable) = finishSetup {
                    MultichainWalletFinishSetupSection(
                        items: items,
                        isFinishEnabled: isSkippable,
                        onBackup: viewModel.backupPressed,
                        onMigration: viewModel.migrationPressed,
                        onEnableNotifications: viewModel.enableNotifications,
                        onEnableBiometry: viewModel.enableBiometry,
                        onFinish: viewModel.skipSetup
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity)
                }

                WalletBalanceMultichainAssetsListView(
                    viewModel: viewModel.assetsListViewModel,
                    showsSkeleton: showsSkeleton
                )
                .padding(.horizontal, 16)

                if !showsSkeleton {
                    MultichainWalletCollectiblesSection(viewModel: viewModel.collectiblesViewModel)
                }
            }
            .padding(.bottom, 16)
            .animation(finishSetupAnimation, value: finishSetup)
        }
        .onChange(of: settlingWalletId) { settlingWalletId in
            settledWalletId = settlingWalletId
        }
        .tkImmediateButtonPresses()
        .refreshable {
            await Task {
                await MinimumRefreshDurationBehavior.perform {
                    await viewModel.refresh()
                }
            }.value
        }
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }

    private var iconButtonsConfig: MultichainWalletIconButtonsSection.Config {
        switch viewModel.state {
        case .pending:
            .shimmer
        case let .ready(iconButtons, _):
            .content(iconButtons)
        }
    }

    private var finishSetup: MultichainWalletViewModel.FinishSetup {
        guard case let .ready(_, finishSetup) = viewModel.state else { return .hidden }
        return finishSetup
    }

    private var showsSkeleton: Bool {
        switch viewModel.state {
        case .pending:
            true
        case .ready:
            false
        }
    }

    private var settlingWalletId: String? {
        showsSkeleton ? nil : viewModel.wallet.id
    }

    private var finishSetupAnimation: Animation? {
        settledWalletId == viewModel.wallet.id ? Layout.sectionAnimation : nil
    }
}

private extension MultichainWalletContentView {
    enum Layout {
        static let sectionAnimation: Animation = WalletBalanceHomeBannersLayout.animation
    }
}

private struct MultichainWalletBalanceSection: View {
    @ObservedObject var viewModel: MultichainWalletBalanceSectionViewModel
    let showsShimmer: Bool

    private var config: BalanceViewConfig {
        showsShimmer ? .shimmer : viewModel.config
    }

    var body: some View {
        BalanceSwiftUIView(
            config: config,
            balanceAction: viewModel.balancePressed,
            addressAction: viewModel.addressPressed,
            addressLongPressAction: viewModel.addressLongPressed,
            batteryAction: viewModel.batteryPressed,
            backupAction: viewModel.backupPressed
        )
        .frame(height: height(for: config), alignment: .top)
        .clipped()
    }

    private func height(for config: BalanceViewConfig) -> CGFloat {
        if case let .content(content) = config, content.address == nil {
            return Layout.heightWithoutAddress
        }
        return Layout.heightWithAddress
    }

    private enum Layout {
        static let heightWithAddress: CGFloat = 128
        static let heightWithoutAddress: CGFloat = 96
    }
}

private struct MultichainWalletHomeBannersSection: View {
    @ObservedObject var viewModel: WalletBalanceHomeBannersViewModel
    let showsShimmer: Bool

    var body: some View {
        if showsShimmer || !viewModel.state.hasAnswered {
            MultichainWalletHomeBannersSkeleton()
        } else {
            WalletBalanceHomeBannersView(viewModel: viewModel)
        }
    }
}

private struct MultichainWalletHomeBannersSkeleton: View {
    var body: some View {
        ShimmerSwiftUIView(
            config: ShimmerSwiftUIView.Config(cornerRadius: .value(Layout.cornerRadius))
        )
        .frame(height: Layout.bannerHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.bottomPadding)
    }

    private enum Layout {
        static let bannerHeight: CGFloat = 90
        static let cornerRadius: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 16
    }
}

private struct MultichainWalletCollectiblesSection: View {
    @ObservedObject var viewModel: WalletBalanceMultichainCollectiblesViewModel

    var body: some View {
        if viewModel.isSectionVisible {
            WalletBalanceMultichainCollectiblesView(viewModel: viewModel)
                .padding(.top, 16)
        }
    }
}

private struct MultichainWalletFinishSetupSection: View {
    let items: [WalletBalanceSetupModel.State.Item]
    let isFinishEnabled: Bool
    let onBackup: () -> Void
    let onMigration: () -> Void
    let onEnableNotifications: () -> Void
    let onEnableBiometry: () -> Void
    let onFinish: () -> Void

    private enum Layout {
        static let skipIconVerticalOffset: CGFloat = 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListTitleView(
                config: .text(
                    TKLocales.FinishSetup.title,
                    accessory: isFinishEnabled
                        ? .init(
                            title: TKLocales.FinishSetup.skip,
                            icon: .TKUIKit.Icons.Size16.eyeDisable,
                            iconVerticalOffset: Layout.skipIconVerticalOffset,
                            foregroundColor: .textSecondary,
                            action: onFinish
                        )
                        : nil
                )
            )
            .padding(.trailing, 8)
            if !items.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.identifier) { index, item in
                        cell(for: item, showsDivider: index < items.count - 1)
                            .transition(.opacity)
                    }
                }
                .asCellsGroup(
                    config: CellsGroupModifier.Config(
                        horizontalPadding: 0,
                        cornerRadius: 16,
                        backgroundColor: .backgroundContent
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func cell(
        for item: WalletBalanceSetupModel.State.Item,
        showsDivider: Bool
    ) -> some View {
        switch item {
        case .backup:
            SetupCell(
                content: SetupCellContent(
                    icon: SetupCellContent.Icon(
                        image: .TKUIKit.Icons.Size28.key,
                        tintColor: .accentOrange,
                        backgroundColor: .accentOrange.opacity(0.12)
                    ),
                    title: TKLocales.FinishSetup.Backup.title,
                    subtitle: SetupCellContent.Subtitle(text: TKLocales.FinishSetup.Backup.description),
                    accessory: .chevron,
                    showsDivider: showsDivider
                ),
                onTap: onBackup
            )
        case let .migration(walletsLeft):
            SetupCell(
                content: SetupCellContent(
                    icon: SetupCellContent.Icon(
                        image: .TKUIKit.Icons.Size28.trayArrowDown,
                        tintColor: .accentBlue,
                        backgroundColor: .accentBlue.opacity(0.12)
                    ),
                    title: TKLocales.FinishSetup.Migration.title,
                    subtitle: SetupCellContent.Subtitle(text: migrationSubtitle(walletsLeft: walletsLeft)),
                    accessory: .chevron,
                    showsDivider: showsDivider
                ),
                onTap: onMigration
            )
        case .notifications:
            SetupCell(
                content: SetupCellContent(
                    icon: SetupCellContent.Icon(
                        image: .TKUIKit.Icons.Size28.bell,
                        tintColor: .accentGreen,
                        backgroundColor: .accentGreen.opacity(0.12)
                    ),
                    title: TKLocales.WalletBalanceList.transactionNotifications,
                    accessory: .toggle(SetupCellContent.ToggleConfig(isOn: false)),
                    showsDivider: showsDivider
                ),
                onToggle: { _ in onEnableNotifications() }
            )
        case .biometry:
            SetupCell(
                content: SetupCellContent(
                    icon: SetupCellContent.Icon(
                        image: .TKUIKit.Icons.Size28.faceId,
                        tintColor: .accentGreen,
                        backgroundColor: .accentGreen.opacity(0.12)
                    ),
                    title: biometryTitle,
                    accessory: .toggle(SetupCellContent.ToggleConfig(isOn: false)),
                    showsDivider: showsDivider
                ),
                onToggle: { _ in onEnableBiometry() }
            )
        }
    }

    private func migrationSubtitle(walletsLeft: Int) -> String {
        TKLocales.FinishSetup.Migration.walletsLeftCount(walletsLeft)
    }

    private var biometryTitle: String {
        switch BiometryProvider().getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics) {
        case let .success(state):
            switch state {
            case .faceID:
                TKLocales.FinishSetup.setupBiometry(TKLocales.SettingsListSecurityConfigurator.faceId)
            case .touchID:
                TKLocales.FinishSetup.setupBiometry(TKLocales.SettingsListSecurityConfigurator.touchId)
            case .none:
                TKLocales.FinishSetup.biometryUnavailable
            }
        case .failure:
            TKLocales.FinishSetup.biometryUnavailable
        }
    }
}

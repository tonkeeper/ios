import LocalAuthentication
import SwiftUI
import TKLocalize
import TKUIKit

struct MultichainWalletRootView: View {
    @ObservedObject var viewModel: MultichainWalletRootViewModel
    @Environment(\.tkPalette) private var palette

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                MultichainWalletBalanceSection(viewModel: viewModel.balanceViewModel)

                MultichainWalletIconButtonsSection(
                    showsSkeleton: viewModel.showsSkeleton,
                    model: viewModel.iconButtonsModel,
                    onSend: viewModel.tapSend,
                    onDeposit: viewModel.tapDeposit,
                    onSwap: viewModel.tapSwap,
                    onStake: viewModel.tapStake
                )

                MultichainWalletHomeBannersSection(viewModel: viewModel.homeBannersViewModel)
                    .id(viewModel.homeBannersViewModel.identity)

                if let raffle = viewModel.rafflePresentation, raffle.shouldShowMainScreenEntry {
                    RaffleEntryPointView(
                        title: raffle.compactTitle,
                        ticketsText: raffle.ticketsText,
                        action: viewModel.tapRaffle
                    )
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .onAppear {
                        viewModel.raffleBannerDidAppear()
                    }
                }

                if !viewModel.showsSkeleton, viewModel.showsFinishSetup {
                    MultichainWalletFinishSetupSection(
                        items: viewModel.finishSetupItems,
                        isFinishEnabled: viewModel.isFinishSetupEnabled,
                        onBackup: viewModel.backupPressed,
                        onMigration: viewModel.migrationPressed,
                        onEnableNotifications: viewModel.enableNotifications,
                        onEnableBiometry: viewModel.enableBiometry,
                        onFinish: viewModel.finishSetup
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                WalletBalanceMultichainAssetsListView(
                    viewModel: viewModel.assetsListViewModel,
                    showsSkeleton: viewModel.showsSkeleton
                )
                .padding(.horizontal, 16)

                if !viewModel.showsSkeleton {
                    MultichainWalletCollectiblesSection(viewModel: viewModel.collectiblesViewModel)
                }
            }
            .padding(.bottom, 16)
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
}

private struct MultichainWalletBalanceSection: View {
    @ObservedObject var viewModel: MultichainWalletBalanceSectionViewModel

    var body: some View {
        BalanceSwiftUIView(
            config: viewModel.config,
            balanceAction: viewModel.balancePressed,
            addressAction: viewModel.addressPressed,
            addressLongPressAction: viewModel.addressLongPressed,
            batteryAction: viewModel.batteryPressed,
            backupAction: viewModel.backupPressed
        )
        .frame(height: height(for: viewModel.config), alignment: .top)
        .clipped()
    }

    /// The address row is the only optional part of the balance view, so the window either
    /// includes it whole or ends above it — clipping partway through it truncated the line.
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

    var body: some View {
        if viewModel.state.showsShimmer {
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
    let items: [MultichainWalletRootViewModel.FinishSetupItem]
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
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        cell(for: item, showsDivider: index < items.count - 1)
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
        for item: MultichainWalletRootViewModel.FinishSetupItem,
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

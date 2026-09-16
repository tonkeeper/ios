import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

@MainActor
final class WalletBalanceHeaderViewModel {
    private(set) var model: BalanceHeaderView.Model?

    var didUpdateModel: ((BalanceHeaderView.Model) -> Void)?

    var onWithdraw: ((Wallet) -> Void)?
    var onDeposit: ((Wallet) -> Void)?
    var onSwap: ((Wallet) -> Void)?
    var onStake: ((Wallet) -> Void)?
    var onBattery: ((Wallet) -> Void)?
    var onBackup: ((Wallet) -> Void)?

    private(set) var wallet: Wallet

    private let totalBalanceModel: WalletTotalBalanceModel
    private let balanceLoader: BalanceLoader
    private let appSettingsStore: AppSettingsStore
    private let appSettings: AppSettings
    private let headerMapper: WalletBalanceHeaderMapper
    private let configuration: Configuration
    private let tooltipsService: TooltipsService
    private let freshnessModel = BalanceFreshnessModel()
    /// What the header is showing while nothing has answered for it. A recompute over the same
    /// cache — rates landing ahead of the balance they will be applied to — is not an answer, and
    /// stepping the amount through it ticks the number twice before the one answer arrives.
    private var unconfirmedTotalBalance: TotalBalance?

    init(
        wallet: Wallet,
        totalBalanceModel: WalletTotalBalanceModel,
        balanceLoader: BalanceLoader,
        walletsStore: WalletsStore,
        appSettingsStore: AppSettingsStore,
        appSettings: AppSettings,
        headerMapper: WalletBalanceHeaderMapper,
        configuration: Configuration,
        tooltipsService: TooltipsService
    ) {
        self.wallet = wallet
        self.totalBalanceModel = totalBalanceModel
        self.balanceLoader = balanceLoader
        self.appSettingsStore = appSettingsStore
        self.appSettings = appSettings
        self.headerMapper = headerMapper
        self.configuration = configuration
        self.tooltipsService = tooltipsService

        totalBalanceModel.didUpdateState = { [weak self] state in
            Task { @MainActor in
                self?.update(state: state)
            }
        }

        walletsStore.addObserver(self) { observer, event in
            Task { @MainActor in
                observer.didGetWalletsStoreEvent(event)
            }
        }

        configuration.addUpdateObserver(self) { observer in
            Task { @MainActor in
                observer.update()
            }
        }

        balanceLoader.addUpdateObserver(self) { observer, update in
            Task { @MainActor in
                observer.didGetBalanceLoaderUpdate(update)
            }
        }

        freshnessModel.didUpdateFreshness = { [weak self] _ in
            self?.update()
        }

        freshnessModel.onNeedsRefresh = { [weak self] in
            self?.refresh()
        }

        update()
    }

    func didAppear() {
        freshnessModel.didAppear()
    }

    func didDisappear() {
        freshnessModel.didDisappear()
    }

    /// The amount is rendered from a cache that outlives the launch, so an appearance and a return
    /// from the background both ask for the load that confirms it.
    private func refresh() {
        Task { [balanceLoader, wallet] in
            await balanceLoader.reloadBalance(wallet: wallet, priority: .userVisible)
        }
    }

    func reload() async {
        await balanceLoader.reloadBalance(wallet: wallet, priority: .userInitiated)
    }

    private func didGetBalanceLoaderUpdate(_ update: BalanceLoaderUpdate) {
        guard update.wallet == wallet, let result = update.result, case .delivered = result else { return }
        freshnessModel.markFresh()
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        switch event {
        case let .didUpdateWalletMetaData(wallet),
             let .didUpdateWalletSetupSettings(wallet),
             let .didUpdateWalletBatterySettings(wallet),
             let .didUpdateWalletMultichain(wallet):
            adopt(wallet: wallet)
        default:
            break
        }
    }

    /// The backup warning, the battery and the buttons all ride on the wallet value, so the header
    /// takes every update to its own wallet rather than keeping the value it was created with.
    private func adopt(wallet: Wallet) {
        guard self.wallet == wallet else { return }
        self.wallet = wallet
        update()
    }

    private func update() {
        guard let state = try? totalBalanceModel.getState() else { return }
        update(state: state)
    }

    private func update(state: WalletTotalBalanceModel.State) {
        let totalBalance = totalBalanceToRender(state: state)
        let model = makeModel(state: state, totalBalance: totalBalance)
        self.model = model
        didUpdateModel?(model)
    }

    /// Held at what it was when the amount went unconfirmed, and taken from the state again as soon
    /// as a load answers for it.
    private func totalBalanceToRender(state: WalletTotalBalanceModel.State) -> TotalBalance? {
        guard freshnessModel.freshness == .pending else {
            unconfirmedTotalBalance = nil
            return state.totalBalanceState?.totalBalance
        }
        let totalBalance = unconfirmedTotalBalance ?? state.totalBalanceState?.totalBalance
        unconfirmedTotalBalance = totalBalance
        return totalBalance
    }

    private func makeModel(
        state: WalletTotalBalanceModel.State,
        totalBalance: TotalBalance?
    ) -> BalanceHeaderView.Model {
        BalanceHeaderView.Model(
            balanceModel: makeBalanceModel(state: state, totalBalance: totalBalance),
            buttonsModel: makeButtonsModel()
        )
    }

    private func makeBalanceModel(
        state: WalletTotalBalanceModel.State,
        totalBalance: TotalBalance?
    ) -> BalanceHeaderBalanceView.Model {
        let backupWarningState = BalanceBackupWarningCheck().check(
            wallet: wallet,
            tonAmount: totalBalance?.balance.tonItems.first?.amount ?? 0
        )
        let balanceColor: TKColor
        let backupButton: BalanceViewContent.BackupButton?
        let backupAction: (() -> Void)?
        switch backupWarningState {
        case .error:
            balanceColor = .accentRed
            backupButton = BalanceViewContent.BackupButton(color: .accentRed)
            backupAction = { [weak self] in
                guard let self else { return }
                onBackup?(wallet)
            }
        case .warning:
            balanceColor = .accentOrange
            backupButton = BalanceViewContent.BackupButton(color: .accentOrange)
            backupAction = { [weak self] in
                guard let self else { return }
                onBackup?(wallet)
            }
        case .none:
            balanceColor = .textPrimary
            backupButton = nil
            backupAction = nil
        }

        let balance: BalanceViewContent.Balance = {
            if state.isSecure {
                return .secure(color: balanceColor)
            }
            return headerMapper.mapTotalBalanceAmount(
                totalBalance: totalBalance,
                color: balanceColor
            )
        }()

        let batteryConfiguration = makeBatteryConfiguration(
            batteryBalance: totalBalance?.batteryBalance
        )
        let batteryAction: (() -> Void)? = batteryConfiguration.map { _ in
            { [weak self] in
                guard let self else { return }
                onBattery?(wallet)
            }
        }

        return BalanceHeaderBalanceView.Model(
            walletIdentifier: wallet.id,
            config: .content(
                BalanceViewContent(
                    balance: balance.settingFreshness(freshnessModel.freshness),
                    address: makeStatusConfiguration(state: state, totalBalance: totalBalance),
                    battery: batteryConfiguration,
                    backupButton: backupButton,
                    amountScope: wallet.id
                )
            ),
            balanceAction: { [weak self] in
                self?.appSettingsStore.toggleIsSecureMode()
            },
            addressAction: { [weak self] in
                self?.copyAddress(state.address)
            },
            batteryAction: batteryAction,
            backupAction: backupAction
        )
    }

    /// The row reports the load, the amount reports itself: a refresh over a confirmed balance says
    /// "updating" without disturbing the number, and only a number nothing has answered for
    /// shimmers.
    private func makeStatusConfiguration(
        state: WalletTotalBalanceModel.State,
        totalBalance: TotalBalance?
    ) -> BalanceHeaderBalanceStatusViewConfig {
        if let connectionStatusModel = makeConnectionStatus(
            backgroundUpdateState: state.backgroundUpdateConnectionState,
            isLoading: state.isLoadingBalance
        ) {
            return BalanceHeaderBalanceStatusViewConfig(state: .connection(connectionStatusModel))
        }

        // Nothing is in flight behind an amount that has not been confirmed, so how old it is is
        // the only honest thing left to say about it.
        if isUnconfirmed(state: state), let totalBalance {
            return BalanceHeaderBalanceStatusViewConfig(
                state: .updated(TKLocales.ConnectionStatus.updatedAt(headerMapper.makeUpdatedDate(totalBalance.date)))
            )
        }

        let addressText: String = {
            if appSettings.addressCopyCount > 2 {
                return state.address.toShort()
            }
            let prefix = wallet.kind == .watchonly
                ? TKLocales.BalanceHeader.address
                : TKLocales.BalanceHeader.yourAddress
            return prefix + state.address.toShort()
        }()

        return BalanceHeaderBalanceStatusViewConfig(
            state: .address(
                addressText,
                tags: wallet.isMultichain
                    ? [WalletMultichainPresentation.badgeTagSwiftUIConfiguration]
                    : wallet.balanceTagSwiftUIConfigurations()
            )
        )
    }

    /// A dropped stream is worth saying only when it leaves the amount unconfirmed: it reconnects
    /// on its own, and announcing that over a balance that has already landed says nothing.
    private func makeConnectionStatus(
        backgroundUpdateState: BackgroundUpdateConnectionState,
        isLoading: Bool
    ) -> BalanceHeaderBalanceStatusViewConfig.ConnectionStatus? {
        if case .noConnection = backgroundUpdateState {
            return BalanceHeaderBalanceStatusViewConfig.ConnectionStatus(
                title: TKLocales.ConnectionStatus.noInternet,
                titleColor: .accentOrange,
                isLoading: false
            )
        }
        guard isLoading else { return nil }
        return BalanceHeaderBalanceStatusViewConfig.ConnectionStatus(
            title: TKLocales.ConnectionStatus.updating,
            titleColor: .textSecondary,
            isLoading: true
        )
    }

    /// The amount is not one a load just answered with: either nothing has confirmed it since the
    /// app came back, or the last attempt failed and this is the value it fell back to.
    private func isUnconfirmed(state: WalletTotalBalanceModel.State) -> Bool {
        if case .previous = state.totalBalanceState {
            return true
        }
        return freshnessModel.freshness == .pending
    }

    private func makeBatteryConfiguration(batteryBalance: BatteryBalance?) -> BatterySwiftUIViewConfig? {
        guard wallet.kind == .regular else { return nil }
        guard !configuration.flag(\.batteryDisabled, network: wallet.network) else { return nil }

        let state: BatterySwiftUIViewConfig.State
        switch batteryBalance?.batteryState {
        case let .fill(percents):
            state = .fill(percents)
        case .negative:
            state = .negative
        case .empty, .none:
            state = .emptyTinted
        }
        return BatterySwiftUIViewConfig(size: .size34, state: state)
    }

    private func makeButtonsModel() -> WalletBalanceHeaderButtonsRedesignView.Model {
        let withdrawButton = WalletBalanceHeaderButtonsRedesignView.Model.Button(
            title: TKLocales.WalletButtons.send,
            icon: .TKUIKit.Icons.Size28.arrowUpOutline,
            isEnabled: wallet.isSendEnable,
            action: { [weak self] in
                guard let self else { return }
                tooltipsService.didPerformTooltipTargetAction(id: .walletBalanceWithdraw)
                onWithdraw?(wallet)
            }
        )
        let depositButton = WalletBalanceHeaderButtonsRedesignView.Model.Button(
            title: TKLocales.WalletButtons.deposit,
            icon: .TKUIKit.Icons.Size28.arrowDownOutline,
            isEnabled: wallet.isReceiveEnable,
            action: { [weak self] in
                guard let self else { return }
                onDeposit?(wallet)
            }
        )
        let swapButton: WalletBalanceHeaderButtonsRedesignView.Model.Button? = {
            guard !configuration.flag(\.isSwapDisable, network: wallet.network) else { return nil }
            return WalletBalanceHeaderButtonsRedesignView.Model.Button(
                title: TKLocales.WalletButtons.swap,
                icon: .TKUIKit.Icons.Size28.swapHorizontalOutline,
                isEnabled: wallet.isSwapEnable,
                action: { [weak self] in
                    guard let self else { return }
                    onSwap?(wallet)
                }
            )
        }()
        let stakeButton: WalletBalanceHeaderButtonsRedesignView.Model.Button? = {
            guard !configuration.flag(\.stakingDisabled, network: wallet.network) else { return nil }
            return WalletBalanceHeaderButtonsRedesignView.Model.Button(
                title: TKLocales.WalletButtons.stake,
                icon: .TKUIKit.Icons.Size28.stakingOutline,
                isEnabled: wallet.isStakeEnable,
                action: { [weak self] in
                    guard let self else { return }
                    onStake?(wallet)
                }
            )
        }()

        return WalletBalanceHeaderButtonsRedesignView.Model(
            withdrawButton: withdrawButton,
            depositButton: depositButton,
            swapButton: swapButton,
            stakeButton: stakeButton,
            withdrawTooltipEnabled: wallet.isSendEnable
        )
    }

    private func copyAddress(_ address: FriendlyAddress) {
        Pasteboard.copy(value: address.toString(), toast: wallet.copyToastConfiguration())

        appSettings.addressCopyCount += 1
        // The third copy drops the "your address" prefix, so the row it was copied from is redrawn.
        if appSettings.addressCopyCount <= 3 {
            update()
        }
    }
}

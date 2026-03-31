import Foundation
import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

protocol WalletBalanceModuleOutput: AnyObject {
    var didSelectTon: ((Wallet) -> Void)? { get set }
    var didSelectJetton: ((Wallet, JettonItem, Bool) -> Void)? { get set }
    var didSelectTronUSDT: ((Wallet) -> Void)? { get set }
    var didSelectEthena: ((Wallet) -> Void)? { get set }
    var didSelectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)? { get set }
    var didSelectCollectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)? { get set }

    var didTapReceive: ((_ wallet: Wallet) -> Void)? { get set }
    var didTapDeposit: ((_ wallet: Wallet) -> Void)? { get set }
    var didTapWithdraw: ((Wallet) -> Void)? { get set }
    var didTapSend: ((Wallet) -> Void)? { get set }
    var didTapScan: (() -> Void)? { get set }
    var didTapBuy: ((Wallet) -> Void)? { get set }
    var didTapSwap: ((Wallet) -> Void)? { get set }
    var didTapStake: ((Wallet) -> Void)? { get set }
    var didTapStory: ((Story) -> Void)? { get set }
    var didTapAllUpdates: (() -> Void)? { get set }

    var didTapBackup: ((Wallet) -> Void)? { get set }
    var didTapBattery: ((Wallet) -> Void)? { get set }

    var didTapManage: ((Wallet) -> Void)? { get set }

    var didRequirePasscode: (() async -> String?)? { get set }

    var didTapStoriesOnboarding: ((String) -> Void)? { get set }
}

protocol WalletBalanceModuleInput: AnyObject {}

protocol WalletBalanceViewModel: AnyObject {
    var didUpdateSnapshot: ((_ snapshot: WalletBalance.Snapshot, _ isAnimated: Bool) -> Void)? { get set }

    var didUpdateItems: (([WalletBalance.ListItem: WalletBalanceListCell.Configuration]) -> Void)? { get set }

    var didChangeWallet: (() -> Void)? { get set }
    var didUpdateHeader: ((BalanceHeaderView.Model) -> Void)? { get set }
    var didCopy: ((ToastPresenter.Configuration) -> Void)? { get set }

    func reloadData()
    func dismissWithdrawTooltip()
    func markWithdrawTooltipInstructionUnderstood()

    @MainActor
    func viewDidLoad()
    @MainActor
    func getListItemCellConfiguration(identifier: String) -> WalletBalanceListCell.Configuration?
    @MainActor
    func getNotificationItemCellConfiguration(identifier: String) -> NotificationBannerCell.Configuration?
}

struct WalletBalanceListModel: @unchecked Sendable {
    let snapshot: WalletBalance.Snapshot
    let listItemsConfigurations: [String: WalletBalanceListCell.Configuration]
    let notificationItemsConfigurations: [String: NotificationBannerCell.Configuration]
}

final class WalletBalanceViewModelImplementation:
    @unchecked Sendable,
    WalletBalanceViewModel,
    WalletBalanceModuleOutput,
    WalletBalanceModuleInput
{
    // MARK: - WalletBalanceModuleOutput

    var didUpdateSnapshot: ((_ snapshot: WalletBalance.Snapshot, _ isAnimated: Bool) -> Void)?
    var didUpdateItems: (([WalletBalance.ListItem: WalletBalanceListCell.Configuration]) -> Void)?

    var didSelectTon: ((Wallet) -> Void)?
    var didSelectJetton: ((Wallet, JettonItem, Bool) -> Void)?
    var didSelectTronUSDT: ((Wallet) -> Void)?
    var didSelectEthena: ((Wallet) -> Void)?
    var didSelectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?
    var didSelectCollectStakingItem: ((
        _ wallet: Wallet,
        _ stakingPoolInfo: StackingPoolInfo,
        _ accountStakingInfo: AccountStackingInfo
    ) -> Void)?

    var didTapReceive: ((_ wallet: Wallet) -> Void)?
    var didTapSend: ((Wallet) -> Void)?
    var didTapWithdraw: ((Wallet) -> Void)?
    var didTapDeposit: ((Wallet) -> Void)?
    var didTapScan: (() -> Void)?
    var didTapBuy: ((Wallet) -> Void)?
    var didTapSwap: ((Wallet) -> Void)?
    var didTapStake: ((Wallet) -> Void)?
    var didTapStory: ((Story) -> Void)?
    var didTapAllUpdates: (() -> Void)?

    var didTapBackup: ((Wallet) -> Void)?
    var didTapBattery: ((Wallet) -> Void)?

    var didTapManage: ((Wallet) -> Void)?

    var didRequirePasscode: (() async -> String?)?

    var didTapStoriesOnboarding: ((String) -> Void)?

    // MARK: - WalletBalanceViewModel

    var didChangeWallet: (() -> Void)?
    var didUpdateHeader: ((BalanceHeaderView.Model) -> Void)?
    var didCopy: ((ToastPresenter.Configuration) -> Void)?
    private var loadBalanceTrace: Trace?

    func viewDidLoad() {
        let balanceItems = try? balanceListModel.getItems()
        let setupState = setupModel.getState()
        let notifications = Array(notificationStore.getState())

        syncQueue.async {
            self.balanceListItems = balanceItems
            self.setupState = setupState
            self.notifications = notifications
        }
        setupObservations()

        let listModel = createWalletBalanceListModel(
            balanceListItems: balanceItems,
            setupState: setupState,
            notifications: notifications
        )
        self.listModel = listModel
        didUpdateSnapshot?(listModel.snapshot, false)

        let storiesState = storiesStore.getState()
        if let totalBalanceModelState = try? totalBalanceModel.getState() {
            let model = syncQueue.sync {
                createHeaderModel(totalBalanceModelState: totalBalanceModelState, storiesState: storiesState)
            }
            didUpdateHeader?(model)
        }
    }

    func reloadData() {
        balanceLoader.loadActiveWalletBalance()
    }

    func dismissWithdrawTooltip() {
        syncQueue.async {
            self.withdrawTooltipService.dismissTooltip()
            self.refreshHeaderLocked()
        }
    }

    func markWithdrawTooltipInstructionUnderstood() {
        syncQueue.async {
            self.withdrawTooltipService.markInstructionUnderstood()
            self.refreshHeaderLocked()
        }
    }

    private func refreshHeaderLocked() {
        guard let totalBalanceModelState = try? self.totalBalanceModel.getState() else { return }
        let storiesState = self.storiesStore.getState()
        let model = self.createHeaderModel(totalBalanceModelState: totalBalanceModelState, storiesState: storiesState)
        DispatchQueue.main.async {
            self.didUpdateHeader?(model)
        }
    }

    func getListItemCellConfiguration(identifier: String) -> WalletBalanceListCell.Configuration? {
        listModel.listItemsConfigurations[identifier]
    }

    func getNotificationItemCellConfiguration(identifier: String) -> NotificationBannerCell.Configuration? {
        listModel.notificationItemsConfigurations[identifier]
    }

    // MARK: - State

    private let syncQueue = DispatchQueue(label: "SyncQueue")

    @MainActor
    private var listModel = WalletBalanceListModel(
        snapshot: WalletBalance.Snapshot(),
        listItemsConfigurations: [:],
        notificationItemsConfigurations: [:]
    )
    private var balanceListItems: WalletBalanceBalanceModel.BalanceListItems?
    private var setupState: WalletBalanceSetupModel.State?
    private var notifications = [NotificationModel]()
    private var stakingUpdateTimer: DispatchSourceTimer?

    // MARK: - Mapper

    // MARK: - Dependencies

    private let balanceListModel: WalletBalanceBalanceModel
    private let balanceLoader: BalanceLoader
    private let setupModel: WalletBalanceSetupModel
    private let totalBalanceModel: WalletTotalBalanceModel
    private let walletsStore: WalletsStore
    private let notificationStore: InternalNotificationsStore
    private let configuration: Configuration
    private let appSettingsStore: AppSettingsStore
    private let listMapper: WalletBalanceListMapper
    private let headerMapper: WalletBalanceHeaderMapper
    private let urlOpener: URLOpener
    private let appSettings: AppSettings
    private let storiesStore: StoriesStore
    private let withdrawTooltipService: WalletBalanceWithdrawTooltipService

    init(
        balanceListModel: WalletBalanceBalanceModel,
        balanceLoader: BalanceLoader,
        setupModel: WalletBalanceSetupModel,
        totalBalanceModel: WalletTotalBalanceModel,
        walletsStore: WalletsStore,
        notificationStore: InternalNotificationsStore,
        configuration: Configuration,
        appSettingsStore: AppSettingsStore,
        listMapper: WalletBalanceListMapper,
        headerMapper: WalletBalanceHeaderMapper,
        urlOpener: URLOpener,
        appSettings: AppSettings,
        storiesStore: StoriesStore,
        withdrawTooltipService: WalletBalanceWithdrawTooltipService
    ) {
        self.balanceListModel = balanceListModel
        self.balanceLoader = balanceLoader
        self.setupModel = setupModel
        self.totalBalanceModel = totalBalanceModel
        self.walletsStore = walletsStore
        self.notificationStore = notificationStore
        self.configuration = configuration
        self.appSettingsStore = appSettingsStore
        self.listMapper = listMapper
        self.headerMapper = headerMapper
        self.urlOpener = urlOpener
        self.appSettings = appSettings
        self.storiesStore = storiesStore
        self.withdrawTooltipService = withdrawTooltipService
    }

    private func setupObservations() {
        totalBalanceModel.didUpdateState = { [weak self] state in
            self?.didUpdateTotalBalanceState(state)
        }
        balanceListModel.didUpdateItems = { [weak self] items in
            guard let self else { return }
            syncQueue.async {
                self.didUpdateBalanceItems(balanceListItems: items)
            }
        }
        setupModel.didUpdateState = { [weak self] state in
            guard let self else { return }
            syncQueue.async {
                self.didUpdateSetupState(setupState: state)
            }
        }
        walletsStore.addObserver(self) { _, event in
            switch event {
            case .didChangeActiveWallet:
                DispatchQueue.main.async {
                    self.didChangeWallet?()
                }
            default:
                break
            }
        }
        notificationStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateNotifications(notifications):
                observer.syncQueue.async {
                    observer.didUpdateNotifications(notifications: notifications)
                }
            }
        }

        storiesStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateState(storiesState):
                observer.didUpdateStoriesState(storiesState)
            }
        }

        configuration.addUpdateObserver(self) { observer in
            observer.syncQueue.async {
                let storiesState = observer.storiesStore.getState()
                guard let totalBalanceModelState = try? observer.totalBalanceModel.getState() else {
                    return
                }
                let model = observer.createHeaderModel(totalBalanceModelState: totalBalanceModelState, storiesState: storiesState)
                DispatchQueue.main.async {
                    observer.didUpdateHeader?(model)
                }
            }
        }
    }

    private func didUpdateBalanceItems(balanceListItems: WalletBalanceBalanceModel.BalanceListItems) {
        self.balanceListItems = balanceListItems
        let listModel = self.createWalletBalanceListModel(
            balanceListItems: balanceListItems,
            setupState: setupState,
            notifications: notifications
        )
        DispatchQueue.main.async {
            self.listModel = listModel
            self.didUpdateSnapshot?(listModel.snapshot, false)
        }
        self.stopStakingItemsUpdateTimer()
        self.startStakingItemsUpdateTimer(
            wallet: balanceListItems.wallet,
            stakingItems: balanceListItems.items.getStakingItems()
        )
    }

    private func didUpdateSetupState(setupState: WalletBalanceSetupModel.State?) {
        self.setupState = setupState
        let listModel = self.createWalletBalanceListModel(
            balanceListItems: balanceListItems,
            setupState: setupState,
            notifications: notifications
        )
        DispatchQueue.main.async {
            self.listModel = listModel
            self.didUpdateSnapshot?(listModel.snapshot, false)
        }
    }

    private func didUpdateNotifications(notifications: [NotificationModel]) {
        self.notifications = notifications
        let listModel = self.createWalletBalanceListModel(
            balanceListItems: balanceListItems,
            setupState: setupState,
            notifications: notifications
        )
        DispatchQueue.main.async {
            self.listModel = listModel
            self.didUpdateSnapshot?(listModel.snapshot, false)
        }
    }

    func didUpdateStoriesState(_ storiesState: StoriesStore.State) {
        syncQueue.async {
            guard let totalBalanceModelState = try? self.totalBalanceModel.getState() else { return }
            let storiesState = self.storiesStore.getState()
            let model = self.createHeaderModel(totalBalanceModelState: totalBalanceModelState, storiesState: storiesState)
            DispatchQueue.main.async {
                self.didUpdateHeader?(model)
            }
        }
    }

    private func createWalletBalanceListModel(
        balanceListItems: WalletBalanceBalanceModel.BalanceListItems?,
        setupState: WalletBalanceSetupModel.State?,
        notifications: [NotificationModel]
    ) -> WalletBalanceListModel {
        var snapshot = WalletBalance.Snapshot()
        var listItemsConfigurations = [String: WalletBalanceListCell.Configuration]()
        var notificationItemsConfigurations = [String: NotificationBannerCell.Configuration]()

        if !notifications.isEmpty {
            let (section, cellConfigurations) = createNotificationsSection(notifications: notifications)
            notificationItemsConfigurations.merge(cellConfigurations) { $1 }
            snapshot.appendSections([.notifications(section)])
            snapshot.appendItems(section.items.map { .notificationItem($0) }, toSection: .notifications(section))
        }

        snapshot.appendSections([.balanceHeader])
        snapshot.appendItems([.balanceHeader], toSection: .balanceHeader)

        if let setupState {
            let (section, cellConfigurations) = createSetupSection(setupState: setupState)
            listItemsConfigurations.merge(cellConfigurations) { $1 }
            snapshot.appendSections([.setup(section)])
            snapshot.appendItems(section.items.map { .listItem($0) }, toSection: .setup(section))
        }

        if let balanceListItems {
            let (section, cellConfigurations) = createBalanceSection(balanceListItems: balanceListItems)
            listItemsConfigurations.merge(cellConfigurations) { $1 }
            snapshot.appendSections([.balance(section)])
            snapshot.appendItems(section.items.map { .listItem($0) }, toSection: .balance(section))
        }

        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
        } else {
            snapshot.reloadItems(snapshot.itemIdentifiers)
        }

        return WalletBalanceListModel(
            snapshot: snapshot,
            listItemsConfigurations: listItemsConfigurations,
            notificationItemsConfigurations: notificationItemsConfigurations
        )
    }

    private func createBalanceSection(
        balanceListItems: WalletBalanceBalanceModel.BalanceListItems
    ) -> (section: WalletBalance.BalanceItemsSection, cellConfigurations: [String: WalletBalanceListCell.Configuration]) {
        var cellConfigurations = [String: WalletBalanceListCell.Configuration]()
        var sectionItems = [WalletBalance.ListItem]()
        for balanceListItem in balanceListItems.items {
            switch balanceListItem.balanceItem {
            case let .ton(item):
                let cellConfiguration = listMapper.mapTonItem(
                    item,
                    isSecure: balanceListItems.isSecure,
                    isPinned: balanceListItem.isPinned
                )
                let sectionItem = WalletBalance.ListItem(
                    identifier: item.id
                ) { [weak self] in
                    self?.didSelectTon?(balanceListItems.wallet)
                }
                cellConfigurations[item.id] = cellConfiguration
                sectionItems.append(sectionItem)
            case let .jetton(item):
                let isNetworkBadgeVisible = item.jetton.jettonInfo.isTonUSDT && balanceListItems.wallet.isTronTurnOn
                let cellConfiguration = listMapper.mapJettonItem(
                    item,
                    isSecure: balanceListItems.isSecure,
                    isPinned: balanceListItem.isPinned,
                    isNetworkBadgeVisible: isNetworkBadgeVisible
                )
                let sectionItem = WalletBalance.ListItem(
                    identifier: item.id
                ) { [weak self] in
                    self?.didSelectJetton?(balanceListItems.wallet, item.jetton, !item.price.isZero)
                }
                cellConfigurations[item.id] = cellConfiguration
                sectionItems.append(sectionItem)
            case let .staking(item):
                let cellConfiguration = listMapper.mapStakingItem(
                    item,
                    isSecure: balanceListItems.isSecure,
                    isPinned: balanceListItem.isPinned,
                    isStakingEnable: balanceListItems.wallet.isStakeEnable,
                    stakingCollectHandler: { [weak self] in
                        guard let self,
                              let poolInfo = item.poolInfo else { return }
                        self.didSelectCollectStakingItem?(balanceListItems.wallet, poolInfo, item.info)
                    }
                )
                let sectionItem = WalletBalance.ListItem(
                    identifier: item.id
                ) { [weak self] in
                    guard let self,
                          let poolInfo = item.poolInfo else { return }
                    self.didSelectStakingItem?(balanceListItems.wallet, poolInfo, item.info)
                }
                cellConfigurations[item.id] = cellConfiguration
                sectionItems.append(sectionItem)
            case let .tronUSDT(item):
                if
                    configuration.flag(\.tronDisabled, network: balanceListItems.wallet.network),
                    item.amount.isZero
                { continue }

                let cellConfiguration = listMapper.mapTronUSDTItem(
                    item,
                    isSecure: balanceListItems.isSecure,
                    isPinned: balanceListItem.isPinned
                )
                let sectionItem = WalletBalance.ListItem(
                    identifier: item.id
                ) { [weak self] in
                    self?.didSelectTronUSDT?(balanceListItems.wallet)
                }
                cellConfigurations[item.id] = cellConfiguration
                sectionItems.append(sectionItem)
            case let .ethena(item):
                let cellConfiguration = listMapper.mapEthenaItem(
                    item,
                    isSecure: balanceListItems.isSecure,
                    isPinned: balanceListItem.isPinned
                )

                var accessory: TKListItemAccessory?
                if item.amount.isZero {
                    accessory = .button(
                        TKListItemButtonAccessoryView.Configuration(
                            title: TKLocales.Actions.open,
                            category: .tertiary,
                            action: { [weak self] in
                                self?.didSelectEthena?(balanceListItems.wallet)
                            }
                        )
                    )
                }

                let sectionItem = WalletBalance.ListItem(
                    identifier: item.id,
                    accessory: accessory
                ) { [weak self] in
                    self?.didSelectEthena?(balanceListItems.wallet)
                }
                cellConfigurations[item.id] = cellConfiguration
                sectionItems.append(sectionItem)
            }
        }

        var footerConfiguration: TKListCollectionViewButtonFooterView.Configuration?
        if balanceListItems.canManage {
            footerConfiguration = TKListCollectionViewButtonFooterView.Configuration(
                identifier: .balanceItemsSectionFooterIdentifier,
                content: TKButton.Configuration.Content(title: .plainString(TKLocales.WalletBalanceList.ManageButton.title)),
                action: { [weak self] in
                    self?.didTapManage?(balanceListItems.wallet)
                }
            )
        }

        let section = WalletBalance.BalanceItemsSection(
            items: sectionItems,
            footerConfiguration: footerConfiguration
        )
        return (section, cellConfigurations)
    }

    private func createSetupSection(
        setupState: WalletBalanceSetupModel.State
    ) -> (section: WalletBalance.SetupSection, cellConfigurations: [String: WalletBalanceListCell.Configuration]) {
        var cellConfigurations = [String: WalletBalanceListCell.Configuration]()
        var sectionItems = [WalletBalance.ListItem]()

        for item in setupState.items {
            switch item {
            case .notifications:
                let action: (Bool) -> Void = { [weak self] _ in
                    guard let self else { return }
                    Task {
                        await self.setupModel.turnOnNotifications()
                    }
                }

                let configuration = self.listMapper.createNotificationsConfiguration()
                let notificationsItem = WalletBalance.ListItem(
                    identifier: item.rawValue,
                    accessory: .switch(
                        TKListItemSwitchAccessoryView.Configuration(
                            isOn: false,
                            action: action
                        )
                    ),
                    onSelection: {
                        action(true)
                    }
                )
                cellConfigurations[item.rawValue] = configuration
                sectionItems.append(notificationsItem)
            case .backup:
                let backupConfiguration = self.listMapper.createBackupConfiguration()
                let backupItem = WalletBalance.ListItem(
                    identifier: item.rawValue,
                    accessory: .chevron,
                    onSelection: { [weak self] in
                        guard let self else { return }
                        Task {
                            await MainActor.run {
                                self.didTapBackup?(setupState.wallet)
                            }
                        }
                    }
                )
                cellConfigurations[item.rawValue] = backupConfiguration
                sectionItems.append(backupItem)
            case .biometry:
                let action: (Bool) -> Void = { [weak self] isOn in
                    guard let self else { return }
                    Task {
                        if isOn {
                            guard let passcode = await self.didRequirePasscode?() else {
                                self.syncQueue.async {
                                    self.didUpdateSetupState(setupState: setupState)
                                }
                                return
                            }

                            try self.setupModel.turnOnBiometry(passcode: passcode)
                        } else {
                            try self.setupModel.turnOffBiometry()
                        }
                    }
                }

                let biometryConfiguration = self.listMapper.createBiometryConfiguration()
                let biometryItem = WalletBalance.ListItem(
                    identifier: item.rawValue,
                    accessory: .switch(
                        TKListItemSwitchAccessoryView.Configuration(
                            isOn: false,
                            action: action
                        )
                    ),
                    onSelection: {
                        action(true)
                    }
                )
                cellConfigurations[item.rawValue] = biometryConfiguration
                sectionItems.append(biometryItem)
            }
        }

        var headerButtonConfiguration: TKButton.Configuration?
        if setupState.isFinishEnable {
            headerButtonConfiguration = .actionButtonConfiguration(category: .secondary, size: .small)
            headerButtonConfiguration?.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.done))
            headerButtonConfiguration?.action = { [weak self] in
                self?.setupModel.finishSetup()
            }
        }

        let headerConfiguration = TKListCollectionViewButtonHeaderView.Configuration(
            identifier: .setupSectionHeaderIdentifier,
            title: TKLocales.FinishSetup.title,
            buttonConfiguration: headerButtonConfiguration
        )

        let section = WalletBalance.SetupSection(
            items: sectionItems,
            headerConfiguration: headerConfiguration
        )
        return (section, cellConfigurations)
    }

    private func createNotificationsSection(notifications: [NotificationModel])
        -> (section: WalletBalance.NotificationSection, cellConfigurations: [String: NotificationBannerCell.Configuration])
    {
        var cellConfigurations = [String: NotificationBannerCell.Configuration]()
        var items = [WalletBalance.NotificationItem]()
        for notification in notifications {
            let actionButton: NotificationBannerView.Model.ActionButton? = {
                guard let action = notification.action else {
                    return nil
                }

                let actionButtonAction: () -> Void
                switch action.type {
                case let .openLink(url):
                    actionButtonAction = { [weak self] in
                        guard let url else { return }
                        self?.urlOpener.open(url: url)
                    }
                }
                return NotificationBannerView.Model.ActionButton(title: action.label, action: actionButtonAction)
            }()
            let cellConfiguration = NotificationBannerCell.Configuration(
                bannerViewConfiguration: NotificationBannerView.Model(
                    title: notification.title,
                    caption: notification.caption,
                    appearance: {
                        switch notification.mode {
                        case .critical:
                            return .accentRed
                        case .warning:
                            return .accentYellow
                        }
                    }(),
                    actionButton: actionButton,
                    closeButton: NotificationBannerView.Model.CloseButton(
                        action: { [weak self] in
                            guard let self else { return }
                            Task {
                                await self.notificationStore.removeNotification(notification, persistant: true)
                            }
                        }
                    )
                )
            )
            let item = WalletBalance.NotificationItem(
                id: notification.id,
                cellConfiguration: cellConfiguration
            )

            cellConfigurations[notification.id] = cellConfiguration
            items.append(item)
        }

        let section = WalletBalance.NotificationSection(
            items: items
        )

        return (section, cellConfigurations)
    }

    private func startStakingItemsUpdateTimer(
        wallet: Wallet,
        stakingItems: [WalletBalanceBalanceModel.Item]
    ) {
        let queue = DispatchQueue(label: "WalletBalanceStakingItemsTimerQueue", qos: .background)
        let timer: DispatchSourceTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer.schedule(deadline: .now(), repeating: 1, leeway: .milliseconds(100))
        timer.resume()
        timer.setEventHandler(handler: { [weak self] in
            guard let self else { return }
            Task {
                await self.updateStakingItemsOnTimer(
                    wallet: wallet,
                    stakingItems: stakingItems
                )
            }
        })
        self.stakingUpdateTimer = timer
    }

    private func stopStakingItemsUpdateTimer() {
        self.stakingUpdateTimer?.cancel()
        self.stakingUpdateTimer = nil
    }

    func updateStakingItemsOnTimer(
        wallet: Wallet,
        stakingItems: [WalletBalanceBalanceModel.Item]
    ) async {
        let listModel = await self.listModel
        let isSecure = self.appSettingsStore.state.isSecureMode
        var listItemsConfigurations = listModel.listItemsConfigurations
        var items = [WalletBalance.ListItem: WalletBalanceListCell.Configuration]()

        for item in stakingItems {
            guard case let .staking(stakingItem) = item.balanceItem else { continue }
            let cellConfiguration = self.listMapper.mapStakingItem(
                stakingItem,
                isSecure: isSecure,
                isPinned: item.isPinned,
                isStakingEnable: wallet.isStakeEnable,
                stakingCollectHandler: { [weak self] in
                    guard let poolInfo = stakingItem.poolInfo else { return }
                    self?.didSelectCollectStakingItem?(wallet, poolInfo, stakingItem.info)
                }
            )
            listItemsConfigurations[stakingItem.id] = cellConfiguration

            let item = WalletBalance.ListItem(
                identifier: stakingItem.id
            ) { [weak self] in
                guard let self,
                      let poolInfo = stakingItem.poolInfo else { return }
                self.didSelectStakingItem?(wallet, poolInfo, stakingItem.info)
            }
            items[item] = cellConfiguration
        }

        let updatedListModel = WalletBalanceListModel(
            snapshot: listModel.snapshot,
            listItemsConfigurations: listItemsConfigurations,
            notificationItemsConfigurations: listModel.notificationItemsConfigurations
        )

        await MainActor.run { [items] in
            self.listModel = updatedListModel
            self.didUpdateItems?(items)
        }
    }

    func createHeaderModel(totalBalanceModelState: WalletTotalBalanceModel.State, storiesState: StoriesStore.State) -> BalanceHeaderView.Model {
        let addressButtonText: String = {
            if self.appSettings.addressCopyCount > 2 {
                totalBalanceModelState.address.toShort()
            } else {
                (totalBalanceModelState.wallet.kind == .watchonly ? TKLocales.BalanceHeader.address : TKLocales.BalanceHeader.yourAddress) + totalBalanceModelState.address.toShort()
            }
        }()

        let statusViewConfiguration: BalanceHeaderBalanceStatusView.Configuration = {
            let action = { [weak self] in
                guard let self else { return }
                self.didTapCopy(
                    address: totalBalanceModelState.address.toString(),
                    toastConfiguration: totalBalanceModelState.wallet.copyToastConfiguration()
                )
                self.appSettings.addressCopyCount += 1
                if self.appSettings.addressCopyCount <= 3 {
                    didUpdateTotalBalanceState(totalBalanceModelState)
                }
            }

            if let connectionStatusModel = self.createConnectionStatusModel(
                backgroundUpdateState: totalBalanceModelState.backgroundUpdateConnectionState,
                isLoading: totalBalanceModelState.isLoadingBalance
            ) {
                return BalanceHeaderBalanceStatusView.Configuration(
                    state: .connection(connectionStatusModel),
                    action: action
                )
            } else if let totalBalanceState = totalBalanceModelState.totalBalanceState, case let .previous(totalBalance) = totalBalanceState {
                return BalanceHeaderBalanceStatusView.Configuration(
                    state: .updated(TKLocales.ConnectionStatus.updatedAt(self.headerMapper.makeUpdatedDate(totalBalance.date))),
                    action: action
                )
            } else {
                return BalanceHeaderBalanceStatusView.Configuration(
                    state: .address(addressButtonText, tags: totalBalanceModelState.wallet.balanceTagConfigurations()),
                    action: action
                )
            }
        }()

        let headerModel = BalanceHeaderBalanceView.Model(
            amountViewConfiguration: createAmountViewConfiguration(state: totalBalanceModelState),
            statusViewConfiguration: statusViewConfiguration
        )

        let updatesModel = self.createUpdatesViewModel(wallet: totalBalanceModelState.wallet, storiesState: storiesState)
        let updatesAction: (() -> Void)? = updatesModel.map { updatesModel in
            { [weak self] in
                guard let self else { return }
                if let story = updatesModel.story {
                    self.didTapStory?(story)
                } else {
                    self.didTapAllUpdates?()
                }
            }
        }
        return BalanceHeaderView.Model(
            balanceModel: headerModel,
            buttonsContent: self.createHeaderButtonsContent(wallet: totalBalanceModelState.wallet),
            updatesViewModel: updatesModel,
            updatesAction: updatesAction
        )
    }

    func createAmountViewConfiguration(state: WalletTotalBalanceModel.State) -> BalanceHeaderBalanceAmountView.Configuration {
        let totalBalanceMapped = self.headerMapper.mapTotalBalance(totalBalance: state.totalBalanceState?.totalBalance)

        let backupWarningState = BalanceBackupWarningCheck().check(
            wallet: state.wallet,
            tonAmount: state.totalBalanceState?.totalBalance?.balance.tonItems.first?.amount ?? 0
        )
        let balanceColor: UIColor
        var backupButton: BalanceHeaderBalanceAmountView.Configuration.BackupButton?
        switch backupWarningState {
        case .error:
            balanceColor = .Accent.red
            backupButton = BalanceHeaderBalanceAmountView.Configuration.BackupButton(
                color: .Accent.red,
                action: { [weak self] in
                    self?.didTapBackup?(state.wallet)
                }
            )
        case .warning:
            balanceColor = .Accent.orange
            backupButton = BalanceHeaderBalanceAmountView.Configuration.BackupButton(
                color: .Accent.orange,
                action: { [weak self] in
                    self?.didTapBackup?(state.wallet)
                }
            )
        case .none:
            balanceColor = .Text.primary
            backupButton = nil
        }

        let amountButtonConfiguration: BalanceHeaderBalanceAmountButton.Configuration = {
            let amountButtonState: BalanceHeaderBalanceAmountButton.State
            if state.isSecure {
                amountButtonState = .secure(color: balanceColor)
            } else {
                amountButtonState = .amount(
                    BalanceHeaderBalanceAmountButton.State.Amount(
                        balance: totalBalanceMapped,
                        color: balanceColor
                    )
                )
            }

            return BalanceHeaderBalanceAmountButton.Configuration(
                state: amountButtonState,
                action: { [weak self] in
                    self?.appSettingsStore.toggleIsSecureMode()
                }
            )
        }()

        let batteryButtonConfiguration = createBatteryButtonConfiguration(
            wallet: state.wallet,
            batteryBalance: state.totalBalanceState?.totalBalance?.batteryBalance
        )

        return BalanceHeaderBalanceAmountView.Configuration(
            amountButtonConfiguration: amountButtonConfiguration,
            batteryButtonConfiguration: batteryButtonConfiguration,
            backupButton: backupButton
        )
    }

    func createBatteryButtonConfiguration(
        wallet: Wallet,
        batteryBalance: BatteryBalance?
    ) -> BalanceHeaderBalanceBatteryButton.Configuration? {
        guard wallet.kind == .regular else { return nil }
        let batteryDisabled = configuration.flag(\.batteryDisabled, network: wallet.network)

        let state: BatteryView.State
        switch (batteryBalance?.batteryState, batteryDisabled) {
        case let (.fill(percents), _):
            state = .fill(percents)
        case let (.empty, disabled):
            if disabled { return nil }
            state = .emptyTinted
        case let (.none, disabled):
            if disabled { return nil }
            state = .emptyTinted
        }
        return BalanceHeaderBalanceBatteryButton.Configuration(
            batteryConfiguration: state,
            action: { [weak self] in
                self?.didTapBattery?(wallet)
            }
        )
    }

    func didUpdateTotalBalanceState(_ state: WalletTotalBalanceModel.State) {
        syncQueue.async {
            if state.isLoadingBalance {
                if self.loadBalanceTrace == nil {
                    self.loadBalanceTrace = Trace(name: "load_balance")
                }
            } else {
                self.loadBalanceTrace?.stop()
                self.loadBalanceTrace = nil
            }

            let storiesState = self.storiesStore.getState()
            let model = self.createHeaderModel(totalBalanceModelState: state, storiesState: storiesState)
            DispatchQueue.main.async {
                self.didUpdateHeader?(model)
            }
        }
    }

    func createConnectionStatusModel(backgroundUpdateState: BackgroundUpdateConnectionState, isLoading: Bool) -> BalanceHeaderBalanceConnectionStatusView.Model? {
        switch (backgroundUpdateState, isLoading) {
        case (.connecting, _):
            return BalanceHeaderBalanceConnectionStatusView.Model(
                title: TKLocales.ConnectionStatus.updating,
                titleColor: .Text.secondary,
                isLoading: true
            )
        case (.connected, false):
            return nil
        case (.connected, true):
            return BalanceHeaderBalanceConnectionStatusView.Model(
                title: TKLocales.ConnectionStatus.updating,
                titleColor: .Text.secondary,
                isLoading: true
            )
        case (.disconnected, _):
            return BalanceHeaderBalanceConnectionStatusView.Model(
                title: TKLocales.ConnectionStatus.updating,
                titleColor: .Text.secondary,
                isLoading: true
            )
        case (.noConnection, _):
            return BalanceHeaderBalanceConnectionStatusView.Model(
                title: TKLocales.ConnectionStatus.noInternet,
                titleColor: .Accent.orange,
                isLoading: false
            )
        }
    }

    func createUpdatesViewModel(wallet: Wallet, storiesState: StoriesStore.State) -> WalletBalanceUpdatesView.Model? {
        guard wallet.kind != .watchonly else { return nil }

        let eligibleStories = storiesState.stories.filter {
            !storiesState.watched.contains($0.story_id)
        }

        let storyToDisplay = eligibleStories.first

        return WalletBalanceUpdatesView.Model(story: storyToDisplay)
    }

    func createHeaderButtonsContent(wallet: Wallet) -> BalanceHeaderView.ButtonsContent {
        if configuration.featureEnabled(.newRampFlow) {
            return .redesign(createHeaderButtonsRedesignModel(wallet: wallet))
        } else {
            return .classic(createHeaderButtonsClassicModel(wallet: wallet))
        }
    }

    func createHeaderButtonsClassicModel(wallet: Wallet) -> WalletBalanceHeaderButtonsView.Model {
        let sendButton = WalletBalanceHeaderButtonsView.Model.Button(
            title: TKLocales.WalletButtons.send,
            icon: .TKUIKit.Icons.Size28.arrowUpOutline,
            isEnabled: wallet.isSendEnable,
            action: { [weak self] in self?.didTapSend?(wallet) }
        )

        let recieveButton: WalletBalanceHeaderButtonsView.Model.Button = WalletBalanceHeaderButtonsView.Model.Button(
            title: TKLocales.WalletButtons.receive,
            icon: .TKUIKit.Icons.Size28.arrowDownOutline,
            isEnabled: wallet.isReceiveEnable,
            action: { [weak self] in self?.didTapReceive?(wallet) }
        )

        let scanButton: WalletBalanceHeaderButtonsView.Model.Button = WalletBalanceHeaderButtonsView.Model.Button(
            title: TKLocales.WalletButtons.scan,
            icon: .TKUIKit.Icons.Size28.qrViewFinderThin,
            isEnabled: wallet.isScanEnable,
            action: { [weak self] in self?.didTapScan?() }
        )

        let swapButton: WalletBalanceHeaderButtonsView.Model.Button? = {
            guard !configuration.flag(\.isSwapDisable, network: wallet.network) else { return nil }
            return WalletBalanceHeaderButtonsView.Model.Button(
                title: TKLocales.WalletButtons.swap,
                icon: .TKUIKit.Icons.Size28.swapHorizontalOutline,
                isEnabled: wallet.isSwapEnable,
                action: { [weak self] in
                    self?.didTapSwap?(wallet)
                }
            )
        }()

        let buyButton: WalletBalanceHeaderButtonsView.Model.Button? = {
            guard !configuration.flag(\.exchangeMethodsDisabled, network: wallet.network) else { return nil }
            return WalletBalanceHeaderButtonsView.Model.Button(
                title: TKLocales.WalletButtons.buy,
                icon: .TKUIKit.Icons.Size28.usd,
                isEnabled: wallet.isBuyEnable,
                action: { [weak self] in
                    self?.didTapBuy?(wallet)
                }
            )
        }()

        let stakeButton: WalletBalanceHeaderButtonsView.Model.Button? = {
            guard !configuration.flag(\.stakingDisabled, network: wallet.network) else { return nil }
            return WalletBalanceHeaderButtonsView.Model.Button(
                title: TKLocales.WalletButtons.stake,
                icon: .TKUIKit.Icons.Size28.stakingOutline,
                isEnabled: wallet.isStakeEnable,
                action: { [weak self] in
                    self?.didTapStake?(wallet)
                }
            )
        }()

        return WalletBalanceHeaderButtonsView.Model(
            sendButton: sendButton,
            recieveButton: recieveButton,
            scanButton: scanButton,
            swapButton: swapButton,
            buyButton: buyButton,
            stakeButton: stakeButton
        )
    }

    func createHeaderButtonsRedesignModel(wallet: Wallet) -> WalletBalanceHeaderButtonsRedesignView.Model {
        let withdrawButton = WalletBalanceHeaderButtonsRedesignView.Model.Button(
            title: TKLocales.WalletButtons.withdraw,
            icon: .TKUIKit.Icons.Size28.arrowUpOutline,
            isEnabled: wallet.isSendEnable, // TODO: - enabled flag
            action: { [weak self] in
                self?.markWithdrawTooltipInstructionUnderstood()
                self?.didTapWithdraw?(wallet)
            }
        )
        let depositButton = WalletBalanceHeaderButtonsRedesignView.Model.Button(
            title: TKLocales.WalletButtons.deposit,
            icon: .TKUIKit.Icons.Size28.arrowDownOutline,
            isEnabled: wallet.isReceiveEnable, // TODO: - enabled flag
            action: { [weak self] in self?.didTapDeposit?(wallet) }
        )

        let swapButton: WalletBalanceHeaderButtonsRedesignView.Model.Button? = {
            guard !configuration.flag(\.isSwapDisable, network: wallet.network) else { return nil }
            return WalletBalanceHeaderButtonsRedesignView.Model.Button(
                title: TKLocales.WalletButtons.swap,
                icon: .TKUIKit.Icons.Size28.swapHorizontalOutline,
                isEnabled: wallet.isSwapEnable,
                action: { [weak self] in self?.didTapSwap?(wallet) }
            )
        }()
        let stakeButton: WalletBalanceHeaderButtonsRedesignView.Model.Button? = {
            guard !configuration.flag(\.stakingDisabled, network: wallet.network) else { return nil }
            return WalletBalanceHeaderButtonsRedesignView.Model.Button(
                title: TKLocales.WalletButtons.stake,
                icon: .TKUIKit.Icons.Size28.stakingOutline,
                isEnabled: wallet.isStakeEnable,
                action: { [weak self] in self?.didTapStake?(wallet) }
            )
        }()

        return WalletBalanceHeaderButtonsRedesignView.Model(
            withdrawButton: withdrawButton,
            depositButton: depositButton,
            swapButton: swapButton,
            stakeButton: stakeButton,
            tooltip: wallet.isSendEnable && withdrawTooltipService.shouldShowTooltip()
                ? WalletBalanceHeaderButtonsRedesignView.Model.Tooltip(
                    title: TKLocales.WalletButtons.sendFromHere,
                    badgeTitle: TKLocales.Common.new
                )
                : nil
        )
    }

    func didTapCopy(address: String, toastConfiguration: ToastPresenter.Configuration) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        UIPasteboard.general.string = address

        didCopy?(toastConfiguration)
    }
}

private extension String {
    static let balanceItemsSectionFooterIdentifier = "BalanceItemsSectionFooterIdentifier"
    static let setupSectionHeaderIdentifier = "SetupSectionHeaderIdentifier"
    static let storiesOnboardingServerId = "onboarding"
}

private extension Array where Element == WalletBalanceBalanceModel.Item {
    func getStakingItems() -> [WalletBalanceBalanceModel.Item] {
        self.compactMap {
            guard case .staking = $0.balanceItem else {
                return nil
            }
            return $0
        }
    }
}

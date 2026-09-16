import Foundation
import KeeperCore
import SwiftUI
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

protocol WalletBalanceModuleOutput: AnyObject {
    var didSelectTon: ((Wallet) -> Void)? { get set }
    var didSelectJetton: ((Wallet, JettonItem, Bool) -> Void)? { get set }
    var didSelectTronUSDT: ((Wallet) -> Void)? { get set }
    var didSelectTronTRX: ((Wallet) -> Void)? { get set }
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

    var didTapDeposit: ((_ wallet: Wallet) -> Void)? { get set }
    var didTapWithdraw: ((Wallet) -> Void)? { get set }
    var didTapSwap: ((Wallet) -> Void)? { get set }
    var didTapStake: ((Wallet) -> Void)? { get set }

    var didTapBackup: ((Wallet) -> Void)? { get set }
    var didTapBattery: ((Wallet) -> Void)? { get set }

    var didTapManage: ((Wallet) -> Void)? { get set }
    var didTapOpenCryptoAssets: (() -> Void)? { get set }

    var didRequirePasscode: (() async -> String?)? { get set }

    var collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel { get }

    var didRequestBannerDeeplinkHandling: ((Deeplink) -> Void)? { get set }
}

protocol WalletBalanceModuleInput: AnyObject {}

protocol WalletBalanceViewModel: AnyObject {
    var didUpdateSnapshot: ((_ snapshot: WalletBalance.Snapshot, _ isAnimated: Bool) -> Void)? { get set }

    var didUpdateItems: (([WalletBalance.ListItem: WalletBalanceListCell.Configuration]) -> Void)? { get set }

    var didChangeWallet: (() -> Void)? { get set }
    var didChangeHomeBannersViewModel: (() -> Void)? { get set }
    var didUpdateHeader: ((BalanceHeaderView.Model) -> Void)? { get set }
    var didCopy: ((ToastPresenter.Configuration) -> Void)? { get set }

    func reloadData()

    @MainActor
    func viewDidLoad()
    @MainActor
    func viewWillAppear()
    @MainActor
    func viewDidDisappear()
    @MainActor
    func getListItemCellConfiguration(identifier: String) -> WalletBalanceListCell.Configuration?
    @MainActor
    func getNotificationItemCellConfiguration(identifier: String) -> NotificationBannerCell.Configuration?

    var collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel { get }

    var homeBannersViewModel: WalletBalanceHomeBannersViewModel { get }

    @MainActor
    func reloadCollectibles() async

    @MainActor
    func tapCryptoAssetsManage()

    @MainActor
    func tapCryptoAssetsOpen()

    func expandMoreAssets()

    @MainActor
    var moreAssetsPreviewAvatars: [AssetAvatarViewImageSource] { get }
}

struct WalletBalanceListModel: @unchecked Sendable {
    let snapshot: WalletBalance.Snapshot
    let listItemsConfigurations: [String: WalletBalanceListCell.Configuration]
    let notificationItemsConfigurations: [String: NotificationBannerCell.Configuration]
    let moreAssetsPreviewAvatars: [AssetAvatarViewImageSource]
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
    var didSelectTronTRX: ((Wallet) -> Void)?
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

    var didTapWithdraw: ((Wallet) -> Void)?
    var didTapDeposit: ((Wallet) -> Void)?
    var didTapSwap: ((Wallet) -> Void)?
    var didTapStake: ((Wallet) -> Void)?

    var didTapBackup: ((Wallet) -> Void)?
    var didTapBattery: ((Wallet) -> Void)?

    var didTapManage: ((Wallet) -> Void)?
    var didTapOpenCryptoAssets: (() -> Void)?

    var didRequirePasscode: (() async -> String?)?

    // MARK: - WalletBalanceViewModel

    var didChangeWallet: (() -> Void)?
    var didChangeHomeBannersViewModel: (() -> Void)?
    var didRequestBannerDeeplinkHandling: ((Deeplink) -> Void)?
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
        applyListModel(listModel, isAnimated: false)

        // The screen enters the hierarchy only once its kind of wallet becomes active, so the
        // wallet it is loaded for is not the one it was assembled for, and the change that brought
        // it here landed before the observations above existed.
        updateWalletScopedModels(wallet: try? walletsStore.activeWallet)
    }

    func viewWillAppear() {
        isOnScreen = true
        headerViewModel.didAppear()
    }

    func viewDidDisappear() {
        isOnScreen = false
        headerViewModel.didDisappear()
    }

    func reloadData() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await headerViewModel.reload()
        }
        Task { @MainActor [weak self] in
            await self?.reloadCollectibles()
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
        notificationItemsConfigurations: [:],
        moreAssetsPreviewAvatars: []
    )
    private var balanceListItems: WalletBalanceBalanceModel.BalanceListItems?
    private var setupState: WalletBalanceSetupModel.State?
    private var notifications = [NotificationModel]()
    private var stakingUpdateTimer: DispatchSourceTimer?
    private var isMoreAssetsExpanded = false
    @MainActor
    private var isOnScreen = false

    @MainActor
    var moreAssetsPreviewAvatars: [AssetAvatarViewImageSource] {
        listModel.moreAssetsPreviewAvatars
    }

    // MARK: - Mapper

    // MARK: - Dependencies

    private let balanceListModel: WalletBalanceBalanceModel
    private let balanceLoader: BalanceLoader
    private let setupModel: WalletBalanceSetupModel
    private let makeHeaderViewModel: (Wallet) -> WalletBalanceHeaderViewModel
    private var headerViewModels = [String: WalletBalanceHeaderViewModel]()
    private var headerViewModel: WalletBalanceHeaderViewModel
    private let walletsStore: WalletsStore
    private let notificationStore: InternalNotificationsStore
    private let configuration: Configuration
    private let appSettingsStore: AppSettingsStore
    private let listMapper: WalletBalanceListMapper
    private let urlOpener: URLOpener
    let collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel
    private(set) var homeBannersViewModel: WalletBalanceHomeBannersViewModel
    private let makeHomeBannersViewModel: (Wallet) -> WalletBalanceHomeBannersViewModel
    private var homeBannersViewModels = [HomeBannersIdentity: WalletBalanceHomeBannersViewModel]()

    private var isBannersSectionVisible = false

    var shouldShowBannersSection: Bool {
        isBannersSectionVisible
    }

    var shouldShowCollectiblesSection: Bool {
        (try? walletsStore.activeWallet) != nil
    }

    @MainActor
    init(
        wallet: Wallet,
        balanceListModel: WalletBalanceBalanceModel,
        balanceLoader: BalanceLoader,
        setupModel: WalletBalanceSetupModel,
        makeHeaderViewModel: @escaping (Wallet) -> WalletBalanceHeaderViewModel,
        walletsStore: WalletsStore,
        notificationStore: InternalNotificationsStore,
        configuration: Configuration,
        appSettingsStore: AppSettingsStore,
        listMapper: WalletBalanceListMapper,
        urlOpener: URLOpener,
        collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel,
        makeHomeBannersViewModel: @escaping (Wallet) -> WalletBalanceHomeBannersViewModel
    ) {
        self.balanceListModel = balanceListModel
        self.balanceLoader = balanceLoader
        self.setupModel = setupModel
        self.walletsStore = walletsStore
        self.notificationStore = notificationStore
        self.configuration = configuration
        self.appSettingsStore = appSettingsStore
        self.listMapper = listMapper
        self.urlOpener = urlOpener
        self.collectiblesViewModel = collectiblesViewModel
        self.makeHeaderViewModel = makeHeaderViewModel
        let headerViewModel = makeHeaderViewModel(wallet)
        headerViewModels = [wallet.id: headerViewModel]
        self.headerViewModel = headerViewModel
        self.makeHomeBannersViewModel = makeHomeBannersViewModel
        let homeBannersViewModel = makeHomeBannersViewModel(wallet)
        homeBannersViewModels = [HomeBannersIdentity(wallet: wallet): homeBannersViewModel]
        self.homeBannersViewModel = homeBannersViewModel
        bindHeaderViewModel()
        bindHomeBannersViewModel()
    }

    @MainActor
    func bindBannersSectionVisibility() {
        updateWalletScopedModels(wallet: try? walletsStore.activeWallet)
        let isVisible = homeBannersViewModel.isSectionVisible
        syncQueue.sync { [weak self] in
            self?.isBannersSectionVisible = isVisible
        }
    }

    /// One model per wallet: the deck it renders, the dismissals it writes and the scope it reloads
    /// all belong to that wallet alone. Without a wallet there is nothing to re-point it to, and the
    /// screen is on its way out anyway, so it keeps the deck it is showing.
    @MainActor
    private func updateWalletScopedModels(wallet: Wallet?) {
        updateHeaderViewModel(wallet: wallet)
        updateHomeBannersViewModel(wallet: wallet)
    }

    /// The total, the address and the loading flag it renders all belong to one wallet, so a
    /// switch takes that wallet's model rather than re-pointing this one. Without a wallet there is
    /// nothing to re-point it to, and the screen is on its way out anyway, so it keeps the header
    /// it is showing.
    @MainActor
    private func updateHeaderViewModel(wallet: Wallet?) {
        guard let wallet else { return }
        let viewModel = headerViewModel(for: wallet)
        if viewModel !== headerViewModel {
            // A header kept for a wallet nobody is looking at must not redraw the one on screen,
            // nor keep asking for the loads that a visible one is entitled to.
            headerViewModel.didUpdateModel = nil
            headerViewModel.didDisappear()
            headerViewModel = viewModel
            bindHeaderViewModel()
        }
        if isOnScreen {
            viewModel.didAppear()
        }
        if let model = viewModel.model {
            didUpdateHeader?(model)
        }
    }

    @MainActor
    private func headerViewModel(for wallet: Wallet) -> WalletBalanceHeaderViewModel {
        if let viewModel = headerViewModels[wallet.id] {
            return viewModel
        }

        let viewModel = makeHeaderViewModel(wallet)
        headerViewModels[wallet.id] = viewModel
        return viewModel
    }

    @MainActor
    private func bindHeaderViewModel() {
        headerViewModel.didUpdateModel = { [weak self] model in
            self?.didUpdateHeader?(model)
        }
        headerViewModel.onWithdraw = { [weak self] wallet in
            self?.didTapWithdraw?(wallet)
        }
        headerViewModel.onDeposit = { [weak self] wallet in
            self?.didTapDeposit?(wallet)
        }
        headerViewModel.onSwap = { [weak self] wallet in
            self?.didTapSwap?(wallet)
        }
        headerViewModel.onStake = { [weak self] wallet in
            self?.didTapStake?(wallet)
        }
        headerViewModel.onBattery = { [weak self] wallet in
            self?.didTapBattery?(wallet)
        }
        headerViewModel.onBackup = { [weak self] wallet in
            self?.didTapBackup?(wallet)
        }
    }

    @MainActor
    private func updateHomeBannersViewModel(wallet: Wallet?) {
        guard let wallet else { return }
        let viewModel = homeBannersViewModel(for: wallet)
        if viewModel !== homeBannersViewModel {
            // A deck kept for a wallet nobody is looking at must not resize or reveal a section
            // that now belongs to another one.
            homeBannersViewModel.onSectionVisibilityChanged = nil
            homeBannersViewModel = viewModel
            bindHomeBannersViewModel()
            didChangeHomeBannersViewModel?()
        }
        viewModel.loadIfNeeded()
        didUpdateBannersSectionVisibility(isVisible: viewModel.isSectionVisible)
    }

    @MainActor
    private func homeBannersViewModel(for wallet: Wallet) -> WalletBalanceHomeBannersViewModel {
        let identity = HomeBannersIdentity(wallet: wallet)
        if let viewModel = homeBannersViewModels[identity] {
            return viewModel
        }

        let viewModel = makeHomeBannersViewModel(wallet)
        homeBannersViewModels[identity] = viewModel
        return viewModel
    }

    @MainActor
    private func bindHomeBannersViewModel() {
        homeBannersViewModel.onSectionVisibilityChanged = { [weak self] isVisible in
            self?.didUpdateBannersSectionVisibility(isVisible: isVisible)
        }
        homeBannersViewModel.onOpenDeeplink = { [weak self] deeplink in
            self?.didRequestBannerDeeplinkHandling?(deeplink)
        }
    }

    @MainActor
    func reloadCollectibles() async {
        let wallet = try? walletsStore.activeWallet
        await collectiblesViewModel.load(for: wallet)
    }

    @MainActor
    func tapCryptoAssetsManage() {
        guard let balanceListItems,
              balanceListItems.canManage
        else {
            return
        }
        didTapManage?(balanceListItems.wallet)
    }

    @MainActor
    func tapCryptoAssetsOpen() {
        didTapOpenCryptoAssets?()
    }

    func expandMoreAssets() {
        syncQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isMoreAssetsExpanded else { return }
            self.isMoreAssetsExpanded = true
            self.refreshBalanceListSnapshot()
        }
    }

    private func didUpdateBannersSectionVisibility(isVisible: Bool) {
        syncQueue.async { [weak self] in
            self?.applyBannersSectionVisibility(isVisible: isVisible)
        }
    }

    private func applyBannersSectionVisibility(isVisible: Bool) {
        let wasShowing = shouldShowBannersSection
        isBannersSectionVisible = isVisible
        let isShowing = shouldShowBannersSection
        guard wasShowing != isShowing else { return }

        let listModel = createWalletBalanceListModel(
            balanceListItems: balanceListItems,
            setupState: setupState,
            notifications: notifications
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyListModel(listModel, isAnimated: !isShowing)
        }
    }

    private func setupObservations() {
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
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case let .didChangeActiveWallet(_, wallet):
                observer.syncQueue.async {
                    observer.isMoreAssetsExpanded = false
                }
                Task { @MainActor [weak observer] in
                    guard let observer else { return }
                    observer.updateWalletScopedModels(wallet: wallet)
                    observer.collectiblesViewModel.prepare(for: wallet)
                    observer.didChangeWallet?()
                    await observer.collectiblesViewModel.load(for: wallet)
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

        balanceLoader.addUpdateObserver(self) { observer, update in
            observer.syncQueue.async {
                observer.trackLoadBalance(update: update)
            }
        }
    }

    /// The wait the screen is showing, so it is timed for the wallet on it rather than for any
    /// wallet a sweep happens to be refreshing.
    private func trackLoadBalance(update: BalanceLoaderUpdate) {
        guard (try? walletsStore.activeWallet) == update.wallet else { return }
        if update.isLoading {
            if loadBalanceTrace == nil {
                loadBalanceTrace = Trace(name: "load_balance")
            }
        } else {
            loadBalanceTrace?.stop()
            loadBalanceTrace = nil
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
            self.applyListModel(listModel, isAnimated: false)
        }
        self.stopStakingItemsUpdateTimer()
        self.startStakingItemsUpdateTimer(
            wallet: balanceListItems.wallet,
            stakingItems: balanceListItems.items.getStakingItems()
        )
    }

    private func didUpdateSetupState(setupState: WalletBalanceSetupModel.State?) {
        let hadSetupSection = self.setupState != nil
        self.setupState = setupState
        let listModel = self.createWalletBalanceListModel(
            balanceListItems: balanceListItems,
            setupState: setupState,
            notifications: notifications
        )
        let animateRemoval = hadSetupSection && setupState == nil
        DispatchQueue.main.async {
            self.applyListModel(listModel, isAnimated: animateRemoval)
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
            self.applyListModel(listModel, isAnimated: false)
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

        if shouldShowBannersSection {
            snapshot.appendSections([.banners])
            snapshot.appendItems([.banners], toSection: .banners)
        }

        if let setupState,
           let (section, cellConfigurations) = createSetupSection(setupState: setupState)
        {
            listItemsConfigurations.merge(cellConfigurations) { $1 }
            snapshot.appendSections([.setup(section)])
            snapshot.appendItems(section.items.map { .listItem($0) }, toSection: .setup(section))
        }

        var moreAssetsPreviewAvatars = [AssetAvatarViewImageSource]()
        if let balanceListItems {
            snapshot.appendSections([.cryptoAssetsHeader(canManage: balanceListItems.canManage)])
            snapshot.appendItems([.cryptoAssetsHeader], toSection: .cryptoAssetsHeader(canManage: balanceListItems.canManage))

            let (section, cellConfigurations, previewAvatars) = createBalanceSection(balanceListItems: balanceListItems)
            moreAssetsPreviewAvatars = previewAvatars
            listItemsConfigurations.merge(cellConfigurations) { $1 }
            snapshot.appendSections([.balance(section)])
            snapshot.appendItems(mapBalanceSnapshotItems(section.items), toSection: .balance(section))
        }

        if shouldShowCollectiblesSection {
            snapshot.appendSections([.collectibles])
            snapshot.appendItems([.collectibles], toSection: .collectibles)
        }

        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
        } else {
            snapshot.reloadItems(snapshot.itemIdentifiers)
        }

        return WalletBalanceListModel(
            snapshot: snapshot,
            listItemsConfigurations: listItemsConfigurations,
            notificationItemsConfigurations: notificationItemsConfigurations,
            moreAssetsPreviewAvatars: moreAssetsPreviewAvatars
        )
    }

    private func refreshBalanceListSnapshot() {
        let listModel = createWalletBalanceListModel(
            balanceListItems: balanceListItems,
            setupState: setupState,
            notifications: notifications
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyListModel(listModel, isAnimated: false)
        }
    }

    @MainActor
    private func applyListModel(_ listModel: WalletBalanceListModel, isAnimated: Bool) {
        collectiblesViewModel.prepare(for: try? walletsStore.activeWallet)
        self.listModel = listModel
        didUpdateSnapshot?(listModel.snapshot, isAnimated)
    }

    private func createBalanceSection(
        balanceListItems: WalletBalanceBalanceModel.BalanceListItems
    ) -> (
        section: WalletBalance.BalanceItemsSection,
        cellConfigurations: [String: WalletBalanceListCell.Configuration],
        moreAssetsPreviewAvatars: [AssetAvatarViewImageSource]
    ) {
        var cellConfigurations = [String: WalletBalanceListCell.Configuration]()
        var sectionItems = [WalletBalance.ListItem]()
        var builtItems = [(listItem: WalletBalance.ListItem, balanceItem: WalletBalanceBalanceModel.Item)]()

        for balanceListItem in balanceListItems.items {
            switch balanceListItem.balanceItem {
            case let .ton(item):
                let cellConfiguration = listMapper.mapTonItem(
                    item,
                    wallet: balanceListItems.wallet,
                    isSecure: balanceListItems.isSecure,
                    isPinned: balanceListItem.isPinned
                )
                let sectionItem = WalletBalance.ListItem(
                    identifier: item.id
                ) { [weak self] in
                    self?.didSelectTon?(balanceListItems.wallet)
                }
                cellConfigurations[item.id] = cellConfiguration
                builtItems.append((sectionItem, balanceListItem))
            case let .jetton(item):
                let isNetworkBadgeVisible = item.jetton.jettonInfo.isTonUSDT && balanceListItems.wallet.tron != nil
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
                builtItems.append((sectionItem, balanceListItem))
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
                builtItems.append((sectionItem, balanceListItem))
            case let .tronUSDT(item):
                if
                    configuration.flag(\.tronDisabled, network: balanceListItems.wallet.network),
                    item.amount.isZero
                {
                    continue
                }

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
                builtItems.append((sectionItem, balanceListItem))
            case let .tronTRX(item):
                if
                    configuration.flag(\.tronDisabled, network: balanceListItems.wallet.network),
                    item.amount.isZero
                {
                    continue
                }

                let cellConfiguration = listMapper.mapTronTRXItem(
                    item,
                    isSecure: balanceListItems.isSecure
                )
                let sectionItem = WalletBalance.ListItem(
                    identifier: item.id
                ) { [weak self] in
                    self?.didSelectTronTRX?(balanceListItems.wallet)
                }
                cellConfigurations[item.id] = cellConfiguration
                builtItems.append((sectionItem, balanceListItem))
            case let .ethena(item):
                let identifier = "ethena_\(item.id)"
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
                    identifier: identifier,
                    accessory: accessory
                ) { [weak self] in
                    self?.didSelectEthena?(balanceListItems.wallet)
                }
                cellConfigurations[identifier] = cellConfiguration
                builtItems.append((sectionItem, balanceListItem))
            }
        }

        let displayedItems = displayedBalanceItems(from: builtItems)
        sectionItems = displayedItems.map(\.listItem)

        let moreAssetsPreviewAvatars: [AssetAvatarViewImageSource]
        if shouldShowMoreAssetsButton(for: builtItems.count) {
            moreAssetsPreviewAvatars = builtItems
                .dropFirst(AssetsListLayout.collapsedVisibleCount)
                .prefix(2)
                .map { WalletBalanceMoreAssetsPreviewMapper.previewAvatarSource(for: $0.balanceItem.balanceItem) }
            sectionItems.append(
                WalletBalance.ListItem(identifier: AssetsListLayout.moreAssetsItemIdentifier, onSelection: nil)
            )
        } else {
            moreAssetsPreviewAvatars = []
        }

        let section = WalletBalance.BalanceItemsSection(items: sectionItems)
        return (section, cellConfigurations, moreAssetsPreviewAvatars)
    }

    private func displayedBalanceItems(
        from builtItems: [(listItem: WalletBalance.ListItem, balanceItem: WalletBalanceBalanceModel.Item)]
    ) -> [(listItem: WalletBalance.ListItem, balanceItem: WalletBalanceBalanceModel.Item)] {
        if isMoreAssetsExpanded || builtItems.count <= AssetsListLayout.moreButtonThreshold {
            return builtItems
        }
        return Array(builtItems.prefix(AssetsListLayout.collapsedVisibleCount))
    }

    private func shouldShowMoreAssetsButton(for itemsCount: Int) -> Bool {
        !isMoreAssetsExpanded && itemsCount > AssetsListLayout.moreButtonThreshold
    }

    private func mapBalanceSnapshotItems(_ items: [WalletBalance.ListItem]) -> [WalletBalance.SnapshotItem] {
        items.map { item in
            if item.identifier == AssetsListLayout.moreAssetsItemIdentifier {
                return .moreAssets
            }
            return .listItem(item)
        }
    }

    private func createSetupSection(
        setupState: WalletBalanceSetupModel.State
    ) -> (section: WalletBalance.SetupSection, cellConfigurations: [String: WalletBalanceListCell.Configuration])? {
        var cellConfigurations = [String: WalletBalanceListCell.Configuration]()
        var sectionItems = [WalletBalance.ListItem]()

        let items = setupState.items.filter { item in
            if case .migration = item { return false }
            return true
        }
        guard !items.isEmpty else { return nil }

        for item in items {
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
                    identifier: item.identifier,
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
                cellConfigurations[item.identifier] = configuration
                sectionItems.append(notificationsItem)
            case .backup:
                let backupConfiguration = self.listMapper.createBackupConfiguration()
                let backupItem = WalletBalance.ListItem(
                    identifier: item.identifier,
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
                cellConfigurations[item.identifier] = backupConfiguration
                sectionItems.append(backupItem)
            case .migration:
                break
            case .biometry:
                let action: (Bool) -> Void = { [weak self] isOn in
                    guard let self else { return }
                    Task {
                        do {
                            if isOn {
                                guard let passcode = await self.didRequirePasscode?() else {
                                    self.syncQueue.async {
                                        self.didUpdateSetupState(setupState: setupState)
                                    }
                                    return
                                }
                                try await self.setupModel.turnOnBiometry(passcode: passcode)
                            } else {
                                try await self.setupModel.turnOffBiometry()
                            }
                        } catch {
                            await MainActor.run {
                                self.didCopy?(.failed)
                            }
                            self.syncQueue.async {
                                self.didUpdateSetupState(setupState: setupState)
                            }
                        }
                    }
                }

                let biometryConfiguration = self.listMapper.createBiometryConfiguration()
                let biometryItem = WalletBalance.ListItem(
                    identifier: item.identifier,
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
                cellConfigurations[item.identifier] = biometryConfiguration
                sectionItems.append(biometryItem)
            }
        }

        var headerButtonConfiguration: TKButton.Configuration?
        if setupState.isFinishEnable {
            headerButtonConfiguration = .actionButtonConfiguration(category: .secondary, size: .small)
            headerButtonConfiguration?.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.done))
            headerButtonConfiguration?.action = { [weak self] in
                self?.setupModel.finishSetup(for: setupState.wallet)
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
            notificationItemsConfigurations: listModel.notificationItemsConfigurations,
            moreAssetsPreviewAvatars: listModel.moreAssetsPreviewAvatars
        )

        await MainActor.run { [items] in
            self.listModel = updatedListModel
            self.didUpdateItems?(items)
        }
    }
}

private extension String {
    static let setupSectionHeaderIdentifier = "SetupSectionHeaderIdentifier"
}

private enum AssetsListLayout {
    static let collapsedVisibleCount = 6
    static let moreButtonThreshold = collapsedVisibleCount + 1
    static let moreAssetsItemIdentifier = "more-assets"
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

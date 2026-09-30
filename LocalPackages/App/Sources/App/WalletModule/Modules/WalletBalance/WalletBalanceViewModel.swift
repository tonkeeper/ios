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

    var didTapOpenCollectibles: (() -> Void)? { get set }
    var didSelectNFT: ((Wallet, NFT) -> Void)? { get set }

    var didRequestBannerDeeplinkHandling: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)? { get set }
}

protocol WalletBalanceModuleInput: AnyObject {}

protocol WalletBalanceViewModel: AnyObject {
    var didUpdateSnapshot: ((_ snapshot: WalletBalance.Snapshot, _ isAnimated: Bool) -> Void)? { get set }

    var didUpdateItems: (([WalletBalance.ListItem: WalletBalanceListCell.Configuration]) -> Void)? { get set }

    var didChangeWallet: (() -> Void)? { get set }
    var didChangeHostedViewModels: (() -> Void)? { get set }
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

    @MainActor
    var collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel { get }

    @MainActor
    var homeBannersViewModel: WalletBalanceHomeBannersViewModel { get }

    @MainActor
    func tapCryptoAssetsManage()

    @MainActor
    func tapCryptoAssetsOpen()

    @MainActor
    func expandMoreAssets()

    @MainActor
    var moreAssetsPreviewAvatars: [AssetAvatarViewImageSource] { get }
}

struct WalletBalanceListModel: @unchecked Sendable {
    let walletId: String?
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

    var didTapOpenCollectibles: (() -> Void)?
    var didSelectNFT: ((Wallet, NFT) -> Void)?

    // MARK: - WalletBalanceViewModel

    var didChangeWallet: (() -> Void)?
    var didChangeHostedViewModels: (() -> Void)?
    var didRequestBannerDeeplinkHandling: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    var didUpdateHeader: ((BalanceHeaderView.Model) -> Void)?
    var didCopy: ((ToastPresenter.Configuration) -> Void)?
    private var loadBalanceTrace: Trace?

    func viewDidLoad() {
        let walletViewModel = activateWalletViewModel(for: try? walletsStore.activeWallet)
        applyWalletContentImmediately(walletViewModel.content)
        setupObservations()

        Task { @MainActor [weak self] in
            await self?.walletViewModel.load()
        }
    }

    func viewWillAppear() {
        isOnScreen = true
        activate(wallet: try? walletsStore.activeWallet)
        walletViewModel.didAppear()
    }

    func viewDidDisappear() {
        isOnScreen = false
        walletViewModel.didDisappear()
    }

    func reloadData() {
        Task { @MainActor [weak self] in
            await self?.walletViewModel.reload()
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
        walletId: nil,
        snapshot: WalletBalance.Snapshot(),
        listItemsConfigurations: [:],
        notificationItemsConfigurations: [:],
        moreAssetsPreviewAvatars: []
    )
    private var walletContent: WalletBalanceWalletViewModel.Content?
    private var notifications = [NotificationModel]()
    @MainActor
    private var stakingUpdateTimer: DispatchSourceTimer?
    @MainActor
    private var isOnScreen = false

    @MainActor
    var moreAssetsPreviewAvatars: [AssetAvatarViewImageSource] {
        listModel.moreAssetsPreviewAvatars
    }

    // MARK: - Dependencies

    private let balanceLoader: BalanceLoader
    private let walletsStore: WalletsStore
    private let notificationStore: InternalNotificationsStore
    private let configuration: Configuration
    private let appSettingsStore: AppSettingsStore
    private let listMapper: WalletBalanceListMapper
    private let urlOpener: URLOpener

    private let makeWalletViewModel: (Wallet) -> WalletBalanceWalletViewModel
    @MainActor
    private var walletViewModels = [String: WalletBalanceWalletViewModel]()
    @MainActor
    private var walletViewModel: WalletBalanceWalletViewModel

    @MainActor
    var homeBannersViewModel: WalletBalanceHomeBannersViewModel {
        walletViewModel.homeBannersViewModel
    }

    @MainActor
    var collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel {
        walletViewModel.collectiblesViewModel
    }

    @MainActor
    init(
        wallet: Wallet,
        balanceLoader: BalanceLoader,
        walletsStore: WalletsStore,
        notificationStore: InternalNotificationsStore,
        configuration: Configuration,
        appSettingsStore: AppSettingsStore,
        listMapper: WalletBalanceListMapper,
        urlOpener: URLOpener,
        makeWalletViewModel: @escaping (Wallet) -> WalletBalanceWalletViewModel
    ) {
        self.balanceLoader = balanceLoader
        self.walletsStore = walletsStore
        self.notificationStore = notificationStore
        self.configuration = configuration
        self.appSettingsStore = appSettingsStore
        self.listMapper = listMapper
        self.urlOpener = urlOpener
        self.makeWalletViewModel = makeWalletViewModel

        let walletViewModel = makeWalletViewModel(wallet)
        walletViewModels = [wallet.id: walletViewModel]
        self.walletViewModel = walletViewModel
        bind(walletViewModel)
    }

    @MainActor
    private func activateWalletViewModel(for wallet: Wallet?) -> WalletBalanceWalletViewModel {
        guard let wallet else { return walletViewModel }
        let viewModel = self.walletViewModel(for: wallet)
        if viewModel !== walletViewModel {
            walletViewModel.resignActive()
            walletViewModel = viewModel
            didChangeHostedViewModels?()
        }
        if let model = viewModel.headerViewModel.model {
            didUpdateHeader?(model)
        }
        return viewModel
    }

    @MainActor
    private func walletViewModel(for wallet: Wallet) -> WalletBalanceWalletViewModel {
        if let viewModel = walletViewModels[wallet.id] {
            return viewModel
        }

        let viewModel = makeWalletViewModel(wallet)
        walletViewModels[wallet.id] = viewModel
        bind(viewModel)
        return viewModel
    }

    @MainActor
    private func bind(_ viewModel: WalletBalanceWalletViewModel) {
        viewModel.didUpdateContent = { [weak self, weak viewModel] content in
            guard let self, let viewModel, viewModel === walletViewModel else { return }
            didUpdateWalletContent(content)
        }
        viewModel.headerViewModel.didUpdateModel = { [weak self, weak viewModel] model in
            guard let self, let viewModel, viewModel === walletViewModel else { return }
            didUpdateHeader?(model)
        }
        viewModel.headerViewModel.onWithdraw = { [weak self] wallet in
            self?.didTapWithdraw?(wallet)
        }
        viewModel.headerViewModel.onDeposit = { [weak self] wallet in
            self?.didTapDeposit?(wallet)
        }
        viewModel.headerViewModel.onSwap = { [weak self] wallet in
            self?.didTapSwap?(wallet)
        }
        viewModel.headerViewModel.onStake = { [weak self] wallet in
            self?.didTapStake?(wallet)
        }
        viewModel.headerViewModel.onBattery = { [weak self] wallet in
            self?.didTapBattery?(wallet)
        }
        viewModel.headerViewModel.onBackup = { [weak self] wallet in
            self?.didTapBackup?(wallet)
        }
        viewModel.homeBannersViewModel.onOpenDeeplink = { [weak self] deeplink, utm in
            self?.didRequestBannerDeeplinkHandling?(deeplink, utm)
        }
        viewModel.collectiblesViewModel.onTapOpenCollectibles = { [weak self] in
            self?.didTapOpenCollectibles?()
        }
        viewModel.collectiblesViewModel.onSelectNFT = { [weak self, weak viewModel] nft in
            guard let viewModel else { return }
            self?.didSelectNFT?(viewModel.wallet, nft)
        }
    }

    @MainActor
    func tapCryptoAssetsManage() {
        let balanceListItems = walletViewModel.content.balanceListItems
        guard balanceListItems.canManage else { return }
        didTapManage?(balanceListItems.wallet)
    }

    @MainActor
    func tapCryptoAssetsOpen() {
        didTapOpenCryptoAssets?()
    }

    @MainActor
    func expandMoreAssets() {
        walletViewModel.expandMoreAssets()
    }

    private func setupObservations() {
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case let .didChangeActiveWallet(_, wallet):
                Task { @MainActor [weak observer] in
                    guard let observer else { return }
                    observer.activate(wallet: wallet)
                    observer.discardOrphanedWalletViewModels()
                }
            case .didAddWallets:
                Task { @MainActor [weak observer] in
                    observer?.discardOrphanedWalletViewModels()
                }
            case let .didDeleteWallet(wallet):
                Task { @MainActor [weak observer] in
                    observer?.discardWalletViewModel(id: wallet.id)
                }
            case .didDeleteAll:
                Task { @MainActor [weak observer] in
                    observer?.discardWalletViewModels()
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

    @MainActor
    private func activate(wallet: Wallet?) {
        let previous = walletViewModel
        let viewModel = activateWalletViewModel(for: wallet)
        guard viewModel !== previous else { return }

        applyWalletContentImmediately(viewModel.content)
        didChangeWallet?()
        if isOnScreen {
            viewModel.didAppear()
        }
        Task { @MainActor [weak self] in
            guard let self, viewModel === walletViewModel else { return }
            await viewModel.load()
        }
    }

    @MainActor
    private func discardWalletViewModel(id: String) {
        guard let viewModel = walletViewModels.removeValue(forKey: id) else { return }
        guard viewModel !== walletViewModel else { return }
        viewModel.resignActive()
    }

    @MainActor
    private func discardOrphanedWalletViewModels() {
        let walletIds = Set(walletsStore.wallets.map(\.id))
        for (id, viewModel) in walletViewModels where !walletIds.contains(id) {
            guard viewModel !== walletViewModel else { continue }
            walletViewModels[id] = nil
            viewModel.resignActive()
        }
    }

    @MainActor
    private func discardWalletViewModels() {
        for viewModel in walletViewModels.values {
            viewModel.resignActive()
        }
        walletViewModels = [walletViewModel.wallet.id: walletViewModel]
    }

    @MainActor
    private func applyWalletContentImmediately(_ content: WalletBalanceWalletViewModel.Content) {
        let notifications = Array(notificationStore.getState())
        let listModel = createWalletBalanceListModel(
            walletContent: content,
            notifications: notifications
        )
        applyListModel(listModel, isAnimated: false)
        startStakingItemsUpdateTimer(for: content)
        syncQueue.async { [weak self] in
            guard let self else { return }
            walletContent = content
            self.notifications = Array(notificationStore.getState())
        }
    }

    @MainActor
    private func didUpdateWalletContent(_ content: WalletBalanceWalletViewModel.Content) {
        syncQueue.async { [weak self] in
            self?.applyWalletContent(content)
        }
        startStakingItemsUpdateTimer(for: content)
    }

    private func applyWalletContent(_ content: WalletBalanceWalletViewModel.Content) {
        let previous = walletContent
        walletContent = content
        let listModel = createWalletBalanceListModel(
            walletContent: content,
            notifications: notifications
        )
        let isSameWallet = previous?.balanceListItems.wallet == content.balanceListItems.wallet
        let isAnimated = isSameWallet
            && ((previous?.showsBannersSection == true && !content.showsBannersSection)
                || (previous?.setupState != nil && content.setupState == nil))
        DispatchQueue.main.async { [weak self] in
            self?.applyListModel(listModel, isAnimated: isAnimated)
        }
    }

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

    private func didUpdateNotifications(notifications: [NotificationModel]) {
        self.notifications = notifications
        let listModel = self.createWalletBalanceListModel(
            walletContent: walletContent,
            notifications: notifications
        )
        DispatchQueue.main.async {
            self.applyListModel(listModel, isAnimated: false)
        }
    }

    private func createWalletBalanceListModel(
        walletContent: WalletBalanceWalletViewModel.Content?,
        notifications: [NotificationModel]
    ) -> WalletBalanceListModel {
        let balanceListItems = walletContent?.balanceListItems
        let setupState = walletContent?.setupState
        let isMoreAssetsExpanded = walletContent?.isMoreAssetsExpanded ?? false
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

        if walletContent?.showsBannersSection == true {
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

            let (section, cellConfigurations, previewAvatars) = createBalanceSection(
                balanceListItems: balanceListItems,
                isMoreAssetsExpanded: isMoreAssetsExpanded
            )
            moreAssetsPreviewAvatars = previewAvatars
            listItemsConfigurations.merge(cellConfigurations) { $1 }
            snapshot.appendSections([.balance(section)])
            snapshot.appendItems(mapBalanceSnapshotItems(section.items), toSection: .balance(section))
        }

        snapshot.appendSections([.collectibles])
        snapshot.appendItems([.collectibles], toSection: .collectibles)

        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
        } else {
            snapshot.reloadItems(snapshot.itemIdentifiers)
        }

        return WalletBalanceListModel(
            walletId: walletContent?.balanceListItems.wallet.id,
            snapshot: snapshot,
            listItemsConfigurations: listItemsConfigurations,
            notificationItemsConfigurations: notificationItemsConfigurations,
            moreAssetsPreviewAvatars: moreAssetsPreviewAvatars
        )
    }

    @MainActor
    private func applyListModel(_ listModel: WalletBalanceListModel, isAnimated: Bool) {
        guard listModel.walletId == nil || listModel.walletId == walletViewModel.wallet.id else { return }
        self.listModel = listModel
        didUpdateSnapshot?(listModel.snapshot, isAnimated)
    }

    private func createBalanceSection(
        balanceListItems: WalletBalanceBalanceModel.BalanceListItems,
        isMoreAssetsExpanded: Bool
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

        let displayedItems = displayedBalanceItems(
            from: builtItems,
            isMoreAssetsExpanded: isMoreAssetsExpanded
        )
        sectionItems = displayedItems.map(\.listItem)

        let moreAssetsPreviewAvatars: [AssetAvatarViewImageSource]
        if !isMoreAssetsExpanded, builtItems.count > AssetsListLayout.moreButtonThreshold {
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
        from builtItems: [(listItem: WalletBalance.ListItem, balanceItem: WalletBalanceBalanceModel.Item)],
        isMoreAssetsExpanded: Bool
    ) -> [(listItem: WalletBalance.ListItem, balanceItem: WalletBalanceBalanceModel.Item)] {
        if isMoreAssetsExpanded || builtItems.count <= AssetsListLayout.moreButtonThreshold {
            return builtItems
        }
        return Array(builtItems.prefix(AssetsListLayout.collapsedVisibleCount))
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
                    Task { @MainActor [weak self] in
                        await self?.walletViewModels[setupState.wallet.id]?.turnOnNotifications()
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
                        Task { @MainActor [weak self] in
                            self?.didTapBackup?(setupState.wallet)
                        }
                    }
                )
                cellConfigurations[item.identifier] = backupConfiguration
                sectionItems.append(backupItem)
            case .migration:
                break
            case .biometry:
                let action: (Bool) -> Void = { [weak self] isOn in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        let walletViewModel = self.walletViewModel
                        do {
                            if isOn {
                                guard let passcode = await didRequirePasscode?() else {
                                    walletViewModel.republishContent()
                                    return
                                }
                                try await walletViewModel.turnOnBiometry(passcode: passcode)
                            } else {
                                try await walletViewModel.turnOffBiometry()
                            }
                        } catch {
                            didCopy?(.failed)
                            walletViewModel.republishContent()
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
                Task { @MainActor [weak self] in
                    self?.walletViewModels[setupState.wallet.id]?.finishSetup()
                }
            }
        }

        let headerConfiguration = TKListCollectionViewButtonHeaderView.Configuration(
            identifier: .setupSectionHeaderIdentifier,
            title: TKLocales.FinishSetup.title,
            buttonConfiguration: headerButtonConfiguration
        )

        let section = WalletBalance.SetupSection(
            items: sectionItems,
            isFinishEnabled: setupState.isFinishEnable,
            walletId: setupState.wallet.id,
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

    @MainActor
    private func startStakingItemsUpdateTimer(for content: WalletBalanceWalletViewModel.Content) {
        stopStakingItemsUpdateTimer()
        startStakingItemsUpdateTimer(
            wallet: content.balanceListItems.wallet,
            stakingItems: content.balanceListItems.items.getStakingItems()
        )
    }

    @MainActor
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

    @MainActor
    private func stopStakingItemsUpdateTimer() {
        self.stakingUpdateTimer?.cancel()
        self.stakingUpdateTimer = nil
    }

    func updateStakingItemsOnTimer(
        wallet: Wallet,
        stakingItems: [WalletBalanceBalanceModel.Item]
    ) async {
        let isSecure = self.appSettingsStore.state.isSecureMode
        var stakingConfigurations = [String: WalletBalanceListCell.Configuration]()
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
            stakingConfigurations[stakingItem.id] = cellConfiguration

            let item = WalletBalance.ListItem(
                identifier: stakingItem.id
            ) { [weak self] in
                guard let self,
                      let poolInfo = stakingItem.poolInfo else { return }
                self.didSelectStakingItem?(wallet, poolInfo, stakingItem.info)
            }
            items[item] = cellConfiguration
        }

        await MainActor.run { [items, stakingConfigurations] in
            guard self.walletViewModel.wallet == wallet else { return }
            let listModel = self.listModel
            self.listModel = WalletBalanceListModel(
                walletId: listModel.walletId,
                snapshot: listModel.snapshot,
                listItemsConfigurations: listModel.listItemsConfigurations.merging(stakingConfigurations) { $1 },
                notificationItemsConfigurations: listModel.notificationItemsConfigurations,
                moreAssetsPreviewAvatars: listModel.moreAssetsPreviewAvatars
            )
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

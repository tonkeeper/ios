import Foundation
import TKUIKit
import TKCore
import KeeperCore
import UIKit
import TKLocalize
import TonSwift

protocol WalletBalanceModuleOutput: AnyObject {
  var didSelectTon: ((Wallet) -> Void)? { get set }
  var didSelectJetton: ((Wallet, JettonItem, Bool) -> Void)? { get set }
  var didSelectStakingItem: (( _ wallet: Wallet,
                               _ stakingPoolInfo: StackingPoolInfo,
                               _ accountStakingInfo: AccountStackingInfo) -> Void)? { get set }
  var didSelectCollectStakingItem: (( _ wallet: Wallet,
                                      _ stakingPoolInfo: StackingPoolInfo,
                                      _ accountStakingInfo: AccountStackingInfo) -> Void)? { get set }
  
  var didTapReceive: ((_ wallet: Wallet) -> Void)? { get set }
  var didTapSend: ((Wallet) -> Void)? { get set }
  var didTapScan: (() -> Void)? { get set }
  var didTapBuy: ((Wallet) -> Void)? { get set }
  var didTapSwap: ((Wallet) -> Void)? { get set }
  var didTapStake: ((Wallet) -> Void)? { get set }
  
  var didTapBackup: ((Wallet) -> Void)? { get set }
  var didTapBattery: ((Wallet) -> Void)? { get set }
  
  var didTapManage: ((Wallet) -> Void)? { get set }
  
  var didRequirePasscode: (() async -> String?)? { get set }
}

protocol WalletBalanceModuleInput: AnyObject {}

protocol WalletBalanceViewModel: AnyObject {
  var didUpdateSnapshot: ((_ snapshot: WalletBalanceViewController.Snapshot, _ isAnimated: Bool) -> Void)? { get set }
  
  var didUpdateItems: (([WalletBalanceListItem: WalletBalanceListCell.Configuration]) -> Void)? { get set }
  
  var didChangeWallet: (() -> Void)? { get set }
  var didUpdateHeader: ((BalanceHeaderView.Model) -> Void)? { get set }
  var didCopy: ((ToastPresenter.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
  func getListItemCellConfiguration(identifier: String) -> WalletBalanceListCell.Configuration?
  func getNotificationItemCellConfiguration(identifier: String) -> NotificationBannerCell.Configuration?
}

struct WalletBalanceListModel {
  let snapshot: WalletBalanceViewController.Snapshot
  let listItemsConfigurations: [String: WalletBalanceListCell.Configuration]
  let notificationItemsConfigurations: [String: NotificationBannerCell.Configuration]
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput, WalletBalanceModuleInput {
  
  // MARK: - WalletBalanceModuleOutput
  
  var didUpdateSnapshot: ((_ snapshot: WalletBalanceViewController.Snapshot, _ isAnimated: Bool) -> Void)?
  var didUpdateItems: (([WalletBalanceListItem : WalletBalanceListCell.Configuration]) -> Void)?
    
  var didSelectTon: ((Wallet) -> Void)?
  var didSelectJetton: ((Wallet, JettonItem, Bool) -> Void)?
  var didSelectStakingItem: (( _ wallet: Wallet,
                               _ stakingPoolInfo: StackingPoolInfo,
                               _ accountStakingInfo: AccountStackingInfo) -> Void)?
  var didSelectCollectStakingItem: (( _ wallet: Wallet,
                                      _ stakingPoolInfo: StackingPoolInfo,
                                      _ accountStakingInfo: AccountStackingInfo) -> Void)?
  
  var didTapReceive: ((_ wallet: Wallet) -> Void)?
  var didTapSend: ((Wallet) -> Void)?
  var didTapScan: (() -> Void)?
  var didTapBuy: ((Wallet) -> Void)?
  var didTapSwap: ((Wallet) -> Void)?
  var didTapStake: ((Wallet) -> Void)?
  
  var didTapBackup: ((Wallet) -> Void)?
  var didTapBattery: ((Wallet) -> Void)?
  
  var didTapManage: ((Wallet) -> Void)?
  
  var didRequirePasscode: (() async -> String?)?
  
  // MARK: - WalletBalanceViewModel
  
  var didChangeWallet: (() -> Void)?
  var didUpdateHeader: ((BalanceHeaderView.Model) -> Void)?
  var didCopy: ((ToastPresenter.Configuration) -> Void)?
  
  @MainActor
  func viewDidLoad() {
    let balanceItems = try? balanceListModel.getItems()
    let setupState = setupModel.getState()
    let notifications = notificationStore.getState()
    
    syncQueue.async {
      self.balanceListItems = balanceItems
      self.setupState = setupState
      self.notifications = notifications
    }
    setupObservations()
    
    let listModel = createWalletBalanceListModel(balanceListItems: balanceItems,
                                                 setupState: setupState,
                                                 notifications: notifications)
    self.listModel = listModel
    didUpdateSnapshot?(listModel.snapshot, false)
    
    if let totalBalanceModelState = try? totalBalanceModel.getState() {
      let model = syncQueue.sync {
        return createHeaderModel(state: totalBalanceModelState)
      }
      didUpdateHeader?(model)
    }
  }
  
  @MainActor
  func getListItemCellConfiguration(identifier: String) -> WalletBalanceListCell.Configuration? {
    listModel.listItemsConfigurations[identifier]
  }
  
  @MainActor
  func getNotificationItemCellConfiguration(identifier: String) -> NotificationBannerCell.Configuration? {
    listModel.notificationItemsConfigurations[identifier]
  }

  // MARK: - State
  
  private let syncQueue = DispatchQueue(label: "SyncQueue")
  
  @MainActor
  private var listModel = WalletBalanceListModel(snapshot: WalletBalanceViewController.Snapshot(),
                                                 listItemsConfigurations: [:],
                                                 notificationItemsConfigurations: [:])
  private var balanceListItems: WalletBalanceBalanceModel.BalanceListItems?
  private var setupState: WalletBalanceSetupModel.State?
  private var notifications = [NotificationModel]()
  private var stakingUpdateTimer: DispatchSourceTimer?
  
  // MARK: - Mapper
  
  // MARK: - Dependencies
  
  private let balanceListModel: WalletBalanceBalanceModel
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
  
  init(balanceListModel: WalletBalanceBalanceModel,
       setupModel: WalletBalanceSetupModel,
       totalBalanceModel: WalletTotalBalanceModel,
       walletsStore: WalletsStore,
       notificationStore: InternalNotificationsStore,
       configuration: Configuration,
       appSettingsStore: AppSettingsStore,
       listMapper: WalletBalanceListMapper,
       headerMapper: WalletBalanceHeaderMapper,
       urlOpener: URLOpener,
       appSettings: AppSettings) {
    self.balanceListModel = balanceListModel
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
    walletsStore.addObserver(self) { observer, event in
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
      case .didUpdateNotifications(let notifications):
        observer.syncQueue.async {
          observer.didUpdateNotifications(notifications: notifications)
        }
      }
    }
    configuration.addUpdateObserver(self) { observer in
      observer.syncQueue.async {
        guard let totalBalanceModelState = try? observer.totalBalanceModel.getState() else { return }
        let model = observer.createHeaderModel(state: totalBalanceModelState)
        DispatchQueue.main.async {
          observer.didUpdateHeader?(model)
        }
      }
    }
  }
  
  private func didUpdateBalanceItems(balanceListItems: WalletBalanceBalanceModel.BalanceListItems) {
    self.balanceListItems = balanceListItems
    let listModel = self.createWalletBalanceListModel(balanceListItems: balanceListItems, 
                                                      setupState: setupState,
                                                      notifications: notifications)
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
    let listModel = self.createWalletBalanceListModel(balanceListItems: balanceListItems,
                                                      setupState: setupState,
                                                      notifications: notifications)
    DispatchQueue.main.async {
      self.listModel = listModel
      self.didUpdateSnapshot?(listModel.snapshot, false)
    }
  }
  
  private func didUpdateNotifications(notifications: [NotificationModel]) {
    self.notifications = notifications
    let listModel = self.createWalletBalanceListModel(balanceListItems: balanceListItems,
                                                      setupState: setupState,
                                                      notifications: notifications)
    DispatchQueue.main.async {
      self.listModel = listModel
      self.didUpdateSnapshot?(listModel.snapshot, false)
    }
  }
  
  private func createWalletBalanceListModel(balanceListItems: WalletBalanceBalanceModel.BalanceListItems?,
                                            setupState: WalletBalanceSetupModel.State?,
                                            notifications: [NotificationModel]) -> WalletBalanceListModel {
    var snapshot = WalletBalanceViewController.Snapshot()
    var listItemsConfigurations = [String: WalletBalanceListCell.Configuration]()
    var notificationItemsConfigurations = [String : NotificationBannerCell.Configuration]()
    
    if !notifications.isEmpty {
      let (section, cellConfigurations) = createNotificationsSection(notifications: notifications)
      notificationItemsConfigurations.merge(cellConfigurations) { $1 }
      snapshot.appendSections([.notifications(section)])
      snapshot.appendItems(section.items, toSection: .notifications(section))
    }
    
    if let setupState {
      let (section, cellConfigurations) = createSetupSection(setupState: setupState)
      listItemsConfigurations.merge(cellConfigurations) { $1 }
      snapshot.appendSections([.setup(section)])
      snapshot.appendItems(section.items, toSection: .setup(section))
    }
    
    if let balanceListItems {
      let (section, cellConfigurations) = createBalanceSection(balanceListItems: balanceListItems)
      listItemsConfigurations.merge(cellConfigurations) { $1 }
      snapshot.appendSections([.balance(section)])
      snapshot.appendItems(section.items, toSection: .balance(section))
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
  ) -> (section: WalletBalanceListSection, cellConfigurations: [String: WalletBalanceListCell.Configuration])  {
    var cellConfigurations = [String: WalletBalanceListCell.Configuration]()
    var sectionItems = [WalletBalanceListItem]()
    balanceListItems.items.forEach { balanceListItem in
      switch balanceListItem.balanceItem {
      case .ton(let item):
        let cellConfiguration = listMapper.mapTonItem(
          item,
          isSecure: balanceListItems.isSecure,
          isPinned: balanceListItem.isPinned
        )
        let sectionItem = WalletBalanceListItem(
          identifier: item.id) { [weak self] in
            self?.didSelectTon?(balanceListItems.wallet)
          }
        cellConfigurations[item.id] = cellConfiguration
        sectionItems.append(sectionItem)
      case .jetton(let item):
        let cellConfiguration = listMapper.mapJettonItem(
          item,
          isSecure: balanceListItems.isSecure,
          isPinned: balanceListItem.isPinned)
        let sectionItem = WalletBalanceListItem(
          identifier: item.id) { [weak self] in
            self?.didSelectJetton?(balanceListItems.wallet, item.jetton, !item.price.isZero)
          }
        cellConfigurations[item.id] = cellConfiguration
        sectionItems.append(sectionItem)
      case .staking(let item):
        let cellConfiguration = listMapper.mapStakingItem(
          item,
          isSecure: balanceListItems.isSecure,
          isPinned: balanceListItem.isPinned,
          isStakingEnable: balanceListItems.wallet.isStakeEnable,
          stakingCollectHandler: { [weak self] in
            guard let self,
                  let poolInfo = item.poolInfo else { return }
            self.didSelectCollectStakingItem?(balanceListItems.wallet, poolInfo, item.info)
          })
        let sectionItem = WalletBalanceListItem(
          identifier: item.id) { [weak self] in
            guard let self,
                  let poolInfo = item.poolInfo else { return }
            self.didSelectStakingItem?(balanceListItems.wallet, poolInfo, item.info)
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
    
    let section = WalletBalanceListSection(
      items: sectionItems,
      footerConfiguration: footerConfiguration
    )
    return (section, cellConfigurations)
  }
  
  private func createSetupSection(
    setupState: WalletBalanceSetupModel.State
  ) -> (section: WalletBalanceSetupSection, cellConfigurations: [String: WalletBalanceListCell.Configuration])  {
    var cellConfigurations = [String: WalletBalanceListCell.Configuration]()
    var sectionItems = [WalletBalanceListItem]()
    
    setupState.items.forEach { item in
      switch item {
      case .notifications:
        let action: (Bool) -> Void = { [weak self] isOn in
          guard let self else { return }
          Task {
            await self.setupModel.turnOnNotifications()
          }
        }
        
        let configuration = self.listMapper.createNotificationsConfiguration()
        let notificationsItem = WalletBalanceListItem(
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
      case .telegramChannel:
        let buttonConfiguration = TKListItemButtonAccessoryView.Configuration(title: TKLocales.Actions.open,
                                                                              category: .tertiary,
                                                                              action: { [weak self] in
          guard let self else {
            return
          }
          guard let telegramChannelURL = self.configuration.tonkeeperNewsUrl else {
            return
          }
          self.urlOpener.open(url: telegramChannelURL)
        })

        let telegramChannelConfiguration = self.listMapper.createTelegramChannelConfiguration()
        let telegramChannelItem = WalletBalanceListItem(
          identifier: item.rawValue,
          accessory: .button(buttonConfiguration),
          onSelection: nil
        )
        cellConfigurations[item.rawValue] = telegramChannelConfiguration
        sectionItems.append(telegramChannelItem)
      case .backup:
        let backupConfiguration = self.listMapper.createBackupConfiguration()
        let backupItem = WalletBalanceListItem(
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
        let biometryItem = WalletBalanceListItem(
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
    
    let section = WalletBalanceSetupSection(
      items: sectionItems,
      headerConfiguration: headerConfiguration
    )
    return (section, cellConfigurations)
  }
  
  private func createNotificationsSection(notifications: [NotificationModel])
  -> (section: WalletBalanceNotificationSection, cellConfigurations: [String: NotificationBannerCell.Configuration]) {
    var cellConfigurations = [String: NotificationBannerCell.Configuration]()
    var items = [WalletBalanceNotificationItem]()
    notifications.forEach { notification in
      let actionButton: NotificationBannerView.Model.ActionButton? = {
        guard let action = notification.action else {
          return nil
        }
        
        let actionButtonAction: (() -> Void)
        switch action.type {
        case .openLink(let url):
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
                await self.notificationStore.removeNotification(notification)
              }
            }
          )
        )
      )
      let item = WalletBalanceNotificationItem(
        id: notification.id,
        cellConfiguration: cellConfiguration
      )
      
      cellConfigurations[notification.id] = cellConfiguration
      items.append(item)
    }
    
    let section = WalletBalanceNotificationSection(
      items: items
    )
    
    return (section, cellConfigurations)
  }
  
  private func startStakingItemsUpdateTimer(wallet: Wallet, 
                                            stakingItems: [WalletBalanceBalanceModel.Item]) {
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
  
  func updateStakingItemsOnTimer(wallet: Wallet, stakingItems: [WalletBalanceBalanceModel.Item]) async {
    let listModel = await self.listModel
    let isSecure = self.appSettingsStore.state.isSecureMode
    var listItemsConfigurations = listModel.listItemsConfigurations
    var items = [WalletBalanceListItem: WalletBalanceListCell.Configuration]()
    
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
      
      let item = WalletBalanceListItem(
        identifier: stakingItem.id) { [weak self] in
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
  
  func createHeaderModel(state: WalletTotalBalanceModel.State) -> BalanceHeaderView.Model {
    let totalBalanceMapped = self.headerMapper.mapTotalBalance(totalBalance: state.totalBalanceState?.totalBalance)
    
    let addressButtonText: String = {
      if self.appSettings.addressCopyCount > 2 {
        state.address.toShort()
      } else {
        (state.wallet.kind == .watchonly ? TKLocales.BalanceHeader.address : TKLocales.BalanceHeader.yourAddress) + state.address.toShort()
      }
    }()
    
    let addressButtonConfiguration = TKButton.Configuration(
      content: TKButton.Configuration.Content(title: .plainString(addressButtonText)),
      textStyle: .body2,
      textColor: .Text.secondary,
      contentAlpha: [.normal: 1, .highlighted: 0.48],
      action: { [weak self] in
        guard let self else { return }
        self.didTapCopy(address: state.address.toString(),
                         toastConfiguration: state.wallet.copyToastConfiguration())
        self.appSettings.addressCopyCount += 1
        if self.appSettings.addressCopyCount <= 3 {
          didUpdateTotalBalanceState(state)
        }
      }
    )
    
    let balanceColor: UIColor
    let backup: BalanceHeaderAmountView.Configuration.Backup
    let backupWarningState = BalanceBackupWarningCheck().check(
      wallet: state.wallet,
      tonAmount: state.totalBalanceState?.totalBalance?.balance.tonItems.first?.amount ?? 0
    )
    switch backupWarningState {
    case .error:
      balanceColor = .Accent.red
      backup = .backup(color: .Accent.red, closure: { [weak self] in
        self?.didTapBackup?(state.wallet)
      })
    case .warning:
      balanceColor = .Accent.orange
      backup = .backup(color: .Accent.orange, closure: { [weak self] in
        self?.didTapBackup?(state.wallet)
      })
    case .none:
      balanceColor = .Text.primary
      backup = .none
    }
  
    let secureState: BalanceHeaderAmountButton.State = state.isSecure ? .secure : .unsecure
    let balanceConfiguration = BalanceHeaderAmountView.Configuration(
      balanceButtonModel: BalanceHeaderAmountButton.Model(
        balance: totalBalanceMapped,
        balanceColor: balanceColor,
        state: secureState,
        tapHandler: { [weak self] in
          guard let self else { return }
          Task {
            await self.appSettingsStore.toggleIsSecureMode()
          }
        }
      ),
      batteryButtonConfiguration: createBatteryButtonConfiguration(
        wallet: state.wallet,
        batteryBalance: state.totalBalanceState?.totalBalance?.batteryBalance
      ),
      backup: backup
    )
    
    let stateDate: String? = {
      guard let totalBalanceState = state.totalBalanceState else { return nil }
      switch totalBalanceState {
      case .current, .none:
        return nil
      case .previous(let totalBalance):
        return TKLocales.ConnectionStatus.updatedAt(self.headerMapper.makeUpdatedDate(totalBalance.date))
      }
    }()
    
    let headerModel = BalanceHeaderBalanceView.Model(
      balanceConfiguration: balanceConfiguration,
      addressButtonConfiguration: addressButtonConfiguration,
      connectionStatusModel: self.createConnectionStatusModel(
        backgroundUpdateState: state.backgroundUpdateConnectionState,
        isLoading: state.isLoadingBalance
      ),
      tags: state.wallet.balanceTagConfigurations(),
      stateDate: stateDate
    )
    
    let model = BalanceHeaderView.Model(
      balanceModel: headerModel,
      buttonsViewModel: self.createHeaderButtonsModel(wallet: state.wallet)
    )
    return model
  }
  
  func createBatteryButtonConfiguration(wallet: Wallet, batteryBalance: BatteryBalance?) -> BalanceHeaderBatteryButton.Configuration? {
    guard wallet.kind == .regular else { return nil }
    let state: BatteryView.State
    switch batteryBalance?.batteryState {
    case .fill(let percents):
      state = .fill(percents)
    case .empty, .none:
      state = .emptyTinted
    }
    return BalanceHeaderBatteryButton.Configuration(
      batteryConfiguration: state,
      action: { [weak self] in
        self?.didTapBattery?(wallet)
      }
    )
  }
  
  func didUpdateTotalBalanceState(_ state: WalletTotalBalanceModel.State) {
    syncQueue.async {
      let model = self.createHeaderModel(state: state)
      DispatchQueue.main.async {
        self.didUpdateHeader?(model)
      }
    }
  }
  
  func createConnectionStatusModel(backgroundUpdateState: BackgroundUpdateConnectionState, isLoading: Bool) -> ConnectionStatusView.Model? {
    switch (backgroundUpdateState, isLoading) {
    case (.connecting, _):
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.updating,
        titleColor: .Text.secondary,
        isLoading: true
      )
    case (.connected, false):
      return nil
    case (.connected, true):
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.updating,
        titleColor: .Text.secondary,
        isLoading: true
      )
    case (.disconnected, _):
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.updating,
        titleColor: .Text.secondary,
        isLoading: true
      )
    case (.noConnection, _):
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.noInternet,
        titleColor: .Accent.orange,
        isLoading: false
      )
    }
  }
  
  func createHeaderButtonsModel(wallet: Wallet) -> WalletBalanceHeaderButtonsView.Model {
    let flags = configuration.flags(isTestnet: wallet.isTestnet)
    let sendButton: WalletBalanceHeaderButtonsView.Model.Button = {
      WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.send,
        icon: .TKUIKit.Icons.Size28.arrowUpOutline,
        isEnabled: wallet.isSendEnable,
        action: { [weak self] in self?.didTapSend?(wallet) }
      )
    }()
    
    let recieveButton: WalletBalanceHeaderButtonsView.Model.Button = {
      WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.receive,
        icon: .TKUIKit.Icons.Size28.arrowDownOutline,
        isEnabled: wallet.isReceiveEnable,
        action: { [weak self] in self?.didTapReceive?(wallet) }
      )
    }()
    
    let scanButton: WalletBalanceHeaderButtonsView.Model.Button = {
      WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.scan,
        icon: .TKUIKit.Icons.Size28.qrViewFinderThin,
        isEnabled: wallet.isScanEnable,
        action: { [weak self] in self?.didTapScan?() }
      )
    }()
    
    let swapButton: WalletBalanceHeaderButtonsView.Model.Button? = {
      guard !flags.isSwapDisable else { return nil }
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
      guard !flags.isExchangeMethodsDisable else { return nil }
      return WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.buy,
        icon: .TKUIKit.Icons.Size28.usd,
        isEnabled: wallet.isBuyEnable,
        action: { [weak self] in
          self?.didTapBuy?(wallet)
        }
      )
    }()
    
    let stakeButton: WalletBalanceHeaderButtonsView.Model.Button = {
      WalletBalanceHeaderButtonsView.Model.Button(
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
  
  func didTapCopy(address: String, toastConfiguration: ToastPresenter.Configuration) {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    UIPasteboard.general.string = address
    
    didCopy?(toastConfiguration)
  }
}

private extension String {
  static let balanceItemsSectionFooterIdentifier = "BalanceItemsSectionFooterIdentifier"
  static let setupSectionHeaderIdentifier = "SetupSectionHeaderIdentifier"
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

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

  var didTapReceive: (() -> Void)? { get set }
  var didTapSend: (() -> Void)? { get set }
  var didTapScan: (() -> Void)? { get set }
  var didTapBuy: ((Wallet) -> Void)? { get set }
  var didTapSwap: (() -> Void)? { get set }
  var didTapStake: ((Wallet) -> Void)? { get set }
  
  var didTapBackup: ((Wallet) -> Void)? { get set }
  
  var didTapManage: ((Wallet) -> Void)? { get set }
  
  var didRequirePasscode: (() async -> String?)? { get set }
}

protocol WalletBalanceModuleInput: AnyObject {}

protocol WalletBalanceViewModel: AnyObject {
  var didUpdateSnapshot: ((_ snapshot: WalletBalanceViewController.Snapshot, _ isAnimated: Bool) -> Void)? { get set }
  
  var didUpdateBalanceItems: (([String: WalletBalanceListCell.Model]) -> Void)? { get set }
  
  var didChangeWallet: (() -> Void)? { get set }
  var didUpdateHeader: ((BalanceHeaderView.Model) -> Void)? { get set }
  var didCopy: ((ToastPresenter.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapFinishSetupButton()
  func getBalanceItemCellModel(identifier: String) -> WalletBalanceListCell.Model?
  func getNotificationCellModel(identifier: String) -> NotificationBannerCell.Model?
  func didSelectItem(identifier: String)
  func didTapManageButton()
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput, WalletBalanceModuleInput {
  
  private struct State {
    let balanceItems: WalletBalanceBalanceModel.BalanceListItems
    let setupState: WalletBalanceSetupModel.State
    let notifications: [NotificationModel]
    let hasManageButton: Bool
  }
  
  // MARK: - WalletBalanceModuleOutput
  
  var didUpdateSnapshot: ((_ snapshot: WalletBalanceViewController.Snapshot, _ isAnimated: Bool) -> Void)?
  
  var didUpdateBalanceItems: (([String: WalletBalanceListCell.Model]) -> Void)?
  
  var didSelectTon: ((Wallet) -> Void)?
  var didSelectJetton: ((Wallet, JettonItem, Bool) -> Void)?
  var didSelectStakingItem: (( _ wallet: Wallet,
                               _ stakingPoolInfo: StackingPoolInfo,
                               _ accountStakingInfo: AccountStackingInfo) -> Void)?
  
  var didTapReceive: (() -> Void)?
  var didTapSend: (() -> Void)?
  var didTapScan: (() -> Void)?
  var didTapBuy: ((Wallet) -> Void)?
  var didTapSwap: (() -> Void)?
  var didTapStake: ((Wallet) -> Void)?
  
  var didTapBackup: ((Wallet) -> Void)?
  
  var didTapManage: ((Wallet) -> Void)?
  
  var didRequirePasscode: (() async -> String?)?
  
  // MARK: - WalletBalanceViewModel
  
  var didChangeWallet: (() -> Void)?
  var didUpdateHeader: ((BalanceHeaderView.Model) -> Void)?
  var didCopy: ((ToastPresenter.Configuration) -> Void)?
  
  func viewDidLoad() {
    balanceListModel.didUpdateItems = { [weak self] items, isSecure in
      self?.didUpdateBalanceItems(items, isSecure: isSecure)
    }
    setupModel.didUpdateState = { [weak self] state in
      self?.didUpdateSetupState(state)
    }
    totalBalanceModel.didUpdateState = { [weak self] state in
      self?.didUpdateTotalBalanceState(state)
    }
    notificationStore.addObserver(self,
                                  notifyOnAdded: true) { observer, newState, oldState in
      observer.didUpdateNotifications(newState)
    }
  }
  
  func getBalanceItemCellModel(identifier: String) -> WalletBalanceListCell.Model? {
    cellModels[identifier]
  }
  
  func getNotificationCellModel(identifier: String) -> NotificationBannerCell.Model? {
    notificationCellModels[identifier]
  }
  
  func didTapFinishSetupButton() {
    setupModel.finishSetup()
  }
  
  func didSelectItem(identifier: String) {
    cellModels[identifier]?.selectionClosure?()
  }
  
  func didTapManageButton() {
    let wallet = walletsStore.getState().activeWallet
    didTapManage?(wallet)
  }
  
  // MARK: - State

  private let actor = SerialActor<Void>()
  private var state = State(
    balanceItems: WalletBalanceBalanceModel.BalanceListItems(
      items: [], 
      canManage: false
    ),
    setupState: .none,
    notifications: [],
  hasManageButton: false)
  private var cellModels = [String: WalletBalanceListCell.Model]()
  private var notificationCellModels = [String: NotificationBannerCell.Model]()
  private var stakingUpdateTimer: DispatchSourceTimer?

  // MARK: - Mapper
  
  // MARK: - Dependencies
  
  private let balanceListModel: WalletBalanceBalanceModel
  private let setupModel: WalletBalanceSetupModel
  private let totalBalanceModel: WalletTotalBalanceModel
  private let walletsStore: WalletsStoreV2
  private let notificationStore: NotificationsStore
  private let configurationStore: ConfigurationStore
  private let listMapper: WalletBalanceListMapper
  private let headerMapper: WalletBalanceHeaderMapper
  private let secureMode: SecureMode
  private let urlOpener: URLOpener
  
  init(balanceListModel: WalletBalanceBalanceModel,
       setupModel: WalletBalanceSetupModel,
       totalBalanceModel: WalletTotalBalanceModel,
       walletsStore: WalletsStoreV2,
       notificationStore: NotificationsStore,
       configurationStore: ConfigurationStore,
       listMapper: WalletBalanceListMapper,
       headerMapper: WalletBalanceHeaderMapper,
       secureMode : SecureMode,
       urlOpener: URLOpener) {
    self.balanceListModel = balanceListModel
    self.setupModel = setupModel
    self.totalBalanceModel = totalBalanceModel
    self.walletsStore = walletsStore
    self.notificationStore = notificationStore
    self.configurationStore = configurationStore
    self.listMapper = listMapper
    self.headerMapper = headerMapper
    self.secureMode = secureMode
    self.urlOpener = urlOpener
  }
}

private extension WalletBalanceViewModelImplementation {
  func didUpdateTotalBalanceState(_ state: WalletTotalBalanceModel.State) {
    Task {
      await actor.addTask(block: {
        let totalBalanceMapped = self.headerMapper.mapTotalBalance(totalBalance: state.totalBalanceState?.totalBalance)
        
        let addressButtonConfiguration = TKButton.Configuration(
          content: TKButton.Configuration.Content(title: .plainString(state.address.toShort())),
          textStyle: .body2,
          textColor: .Text.secondary,
          contentAlpha: [.normal: 1, .highlighted: 0.48],
          action: { [weak self] in
            self?.didTapCopy(address: state.address.toString(),
                             toastConfiguration: state.wallet.copyToastConfiguration())
          }
        )
        
        let balanceColor: UIColor
        let backup: BalanceHeaderAmountView.Model.Backup
        let isNeedToWarnBackup = state.wallet.isBackupAvailable && !state.wallet.hasBackup
        let tonAmount = state.totalBalanceState?.totalBalance.balance.tonBalance.tonBalance.amount ?? 0
        if isNeedToWarnBackup {
          switch tonAmount {
          case _ where tonAmount >= .tonAmountError:
            balanceColor = .Accent.red
            backup = .backup(color: .Accent.red, closure: { [weak self] in
              self?.didTapBackup?(state.wallet)
            })
          case _ where tonAmount > .tonAmountWarning:
            balanceColor = .Accent.orange
            backup = .backup(color: .Accent.orange, closure: { [weak self] in
              self?.didTapBackup?(state.wallet)
            })
          default:
            balanceColor = .Text.primary
            backup = .none
          }
        } else {
          balanceColor = .Text.primary
          backup = .none
        }

        let secureState: BalanceHeaderAmountButton.State = state.isSecure ? .secure : .unsecure
        let balanceModel = BalanceHeaderAmountView.Model(
          balanceButtonModel: BalanceHeaderAmountButton.Model(
            balance: totalBalanceMapped,
            balanceColor: balanceColor,
            state: secureState,
            tapHandler: { [weak self] in
              guard let self else { return }
              Task {
                await self.secureMode.toggle()
              }
            }
          ),
          backup: backup
        )
        
        let stateDate: String? = {
          guard let totalBalanceState = state.totalBalanceState else { return nil }
          switch totalBalanceState {
          case .current:
            return nil
          case .previous(let totalBalance):
            return TKLocales.ConnectionStatus.updated_at(self.headerMapper.makeUpdatedDate(totalBalance.date))
          }
        }()
        
        let headerModel = BalanceHeaderBalanceView.Model(
          balanceModel: balanceModel,
          addressButtonConfiguration: addressButtonConfiguration,
          connectionStatusModel: self.createConnectionStatusModel(backgroundUpdateState: state.backgroundUpdateState),
          tagConfiguration: state.wallet.balanceTagConfiguration(),
          stateDate: stateDate
        )
        
        let model = BalanceHeaderView.Model(
          balanceModel: headerModel,
          buttonsViewModel: self.createHeaderButtonsModel(wallet: state.wallet)
        )
        
        await MainActor.run {
          self.didUpdateHeader?(model)
        }
      })
    }
  }

  func didUpdateBalanceItems(_ items: WalletBalanceBalanceModel.BalanceListItems, isSecure: Bool) {
    Task {
      await self.actor.addTask(block: {
        self.stopStakingItemsUpdateTimer()
        
        let wallet = await self.walletsStore.getState().activeWallet
        var models = [String: WalletBalanceListCell.Model]()
        
        var stakingItems = [BalanceStakingItemModel]()
        for item in items.items {
          switch item {
          case .ton(let item):
            models[item.id] = self.listMapper.mapTonItem(
              item,
              isSecure: isSecure,
              selectionHandler: { [weak self] in
                self?.didSelectTon?(wallet)
              }
            )
          case .jetton(let item):
            models[item.id] = self.listMapper.mapJettonItem(
              item,
              isSecure: isSecure) { [weak self] in
                self?.didSelectJetton?(wallet, item.jetton, !item.price.isZero)
              }
          case .staking(let item):
            stakingItems.append(item)
            models[item.id] = self.listMapper.mapStakingItem(
              item,
              isSecure: isSecure,
              selectionHandler: { [weak self] in
                guard let self,
                      let poolInfo = item.poolInfo else { return }
                self.didSelectStakingItem?(wallet, poolInfo, item.info)
              },
              stakingCollectHandler: {
                print("Collect")
              })
          }
        }

        let state = State(
          balanceItems: items,
          setupState: self.state.setupState,
          notifications: self.state.notifications,
          hasManageButton: items.canManage
        )
        let snapshot = self.createSnapshot(state: state)
        
        self.state = state
        await MainActor.run { [snapshot, models, stakingItems] in
          self.cellModels.merge(models) { $1 }
          self.didUpdateSnapshot?(snapshot, false)
          self.startStakingItemsUpdateTimer(wallet: wallet, stakingItems: stakingItems)
        }
      })
    }
  }
  
  func didUpdateSetupState(_ state: WalletBalanceSetupModel.State) {
    Task {
      await self.actor.addTask(block: {
        let models = self.listMapper.mapSetupState(
          state,
          biometrySelectionHandler: { [weak self] in
            guard let self else { return }
            Task {
              guard let passcode = await self.didRequirePasscode?() else {
                return
              }
              try await self.setupModel.turnOnBiometry(passcode: passcode)
            }
          },
          biometrySwitchHandler: { [weak self] isOn in
            guard let self else { return false }
            do {
              if isOn {
                guard let passcode = await self.didRequirePasscode?() else {
                  return !isOn
                }
                try await setupModel.turnOnBiometry(passcode: passcode)
              } else {
                try await setupModel.turnOffBiometry()
              }
              return isOn
            } catch {
              return !isOn
            }
          },
          telegramChannelSelectionHandler: { [urlOpener = self.urlOpener, configurationStore = self.configurationStore] in
            Task {
              guard let telegramChannelURL = try? await configurationStore.getConfiguration().tonkeeperNewsUrl else {
                return
              }
              await MainActor.run {
                urlOpener.open(url: telegramChannelURL)
              }
            }
          },
          backupSelectionHandler: { [weak self] in
            guard let self else { return }
            Task {
              let wallet = await self.walletsStore.getState().activeWallet
              await MainActor.run {
                self.didTapBackup?(wallet)
              }
            }
          }
        )
        let state = State(balanceItems: self.state.balanceItems,
                          setupState: state,
                          notifications: self.state.notifications,
                          hasManageButton: self.state.balanceItems.canManage)
        let snapshot = self.createSnapshot(state: state)
        self.state = state
        await MainActor.run { [snapshot] in
          self.cellModels.merge(models) { $1 }
          self.didUpdateSnapshot?(snapshot, false)
        }
      })
    }
  }
  
  func didUpdateNotifications(_ notifications: [NotificationModel]) {
    Task {
      await self.actor.addTask(block:{
        let cellModels = notifications.reduce(into: [String: NotificationBannerCell.Model]()) { result, notification in
          let appearance = {
            switch notification.mode {
            case .warning:
              return NotificationBannerView.Model.Appearance.accentYellow
            case .critical:
              return NotificationBannerView.Model.Appearance.accentRed
            }
          }()
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
          
          let model =  NotificationBannerCell.Model(
            title: notification.title,
            caption: notification.caption,
            appearance: appearance,
            actionButton: actionButton,
            closeAction: { [weak self] in
              guard let self else { return }
              Task {
                self.notificationStore.removeNotification(notification)
              }
            }
          )
          result[notification.id] = model
        }
        let state = State(balanceItems: self.state.balanceItems,
                          setupState: self.state.setupState,
                          notifications: notifications,
                          hasManageButton: self.state.balanceItems.canManage)
        let snapshot = self.createSnapshot(state: state)
        self.state = state
        await MainActor.run { [snapshot] in
          self.notificationCellModels = cellModels
          self.didUpdateSnapshot?(snapshot, true)
        }
      })
    }
  }
  
  private func createSnapshot(state: State) -> WalletBalanceViewController.Snapshot {
    var snapshot = WalletBalanceViewController.Snapshot()
    
    if !state.notifications.isEmpty {
      snapshot.appendSections([.notifications])
      let items: [WalletBalanceItem] = state.notifications.map { .notificationItem($0.id) }
      snapshot.appendItems(items, toSection: .notifications)
    }
    
    switch state.setupState {
    case .setup(let setup):
      let items: [WalletBalanceItem] = {
        var items = [WalletBalanceItem]()
        if setup.isBiometryVisible {
          items.append(.balanceItem(WalletBalanceSetupItem.biometry.rawValue))
        }
        if setup.isTelegramChannelVisible {
          items.append(.balanceItem(WalletBalanceSetupItem.telegramChannel.rawValue))
        }
        if setup.isBackupVisible {
          items.append(.balanceItem(WalletBalanceSetupItem.backup.rawValue))
        }
        return items
      }()
      var buttonContent: TKButton.Configuration.Content?
      if setup.isFinishEnable {
        buttonContent = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.done))
      }
      let model = TKListTitleView.Model(
        title: TKLocales.FinishSetup.title,
        textStyle: .label1,
        buttonContent: buttonContent
      )
      let section = WalletBalanceSection.setup(model)
      snapshot.appendSections([section])
      snapshot.appendItems(items, toSection: section)
    case .none:
      break
    }
    
    var items = [WalletBalanceItem]()
    items.append(contentsOf: state.balanceItems.items.map { .balanceItem($0.identifier) })

    snapshot.appendSections([.balance])
    snapshot.appendItems(items, toSection: .balance)
    
    snapshot.appendSections([.manage])
    
    if state.hasManageButton {
      var manageButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
        category: .secondary,
        size: .small
      )
      manageButtonConfiguration.action = { [didTapManage, walletsStore] in
        didTapManage?(walletsStore.getState().activeWallet)
      }
      manageButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Manage"))
      let manageButtonItem = WalletBalanceItem.manageButton(
        TKButtonCell.Model(
          id: "Manage",
          configuration: manageButtonConfiguration,
          padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 0),
          mode: .widthToFit
        )
      )
      
      snapshot.appendItems([manageButtonItem], toSection: .manage)
    }
    
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    
    return snapshot
  }

  func startStakingItemsUpdateTimer(wallet: Wallet, stakingItems: [BalanceStakingItemModel]) {
    let queue = DispatchQueue(label: "WalletBalanceStakingItemsTimerQueue", qos: .background)
    let timer: DispatchSourceTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
    timer.schedule(deadline: .now(), repeating: 1, leeway: .milliseconds(100))
    timer.resume()
    timer.setEventHandler(handler: { [weak self] in
      self?.updateStakingItemsOnTimer(wallet: wallet, stakingItems: stakingItems)
    })
    self.stakingUpdateTimer = timer
  }
  
  func stopStakingItemsUpdateTimer() {
    self.stakingUpdateTimer?.cancel()
    self.stakingUpdateTimer = nil
  }
  
  func updateStakingItemsOnTimer(wallet: Wallet, stakingItems: [BalanceStakingItemModel]) {
    Task {
      await self.actor.addTask(block: {
        var models = [String: WalletBalanceListCell.Model]()
        let isSecure = await self.secureMode.isSecure
        stakingItems.forEach { item in
          models[item.id] = self.listMapper.mapStakingItem(
            item,
            isSecure: isSecure,
            selectionHandler: { [weak self] in
              guard let poolInfo = item.poolInfo else { return }
              self?.didSelectStakingItem?(wallet, poolInfo, item.info)
            },
            stakingCollectHandler: {
              print("Collect")
            })
        }
        
        await MainActor.run { [models] in
          self.cellModels.merge(models) { $1 }
          self.didUpdateBalanceItems?(models)
        }
      })
    }
  }
  
  func createConnectionStatusModel(backgroundUpdateState: BackgroundUpdateStoreV2.State) -> ConnectionStatusView.Model? {
    switch backgroundUpdateState {
    case .connecting:
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.updating,
        titleColor: .Text.secondary,
        isLoading: true
      )
    case .connected:
      return nil
    case .disconnected:
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.updating,
        titleColor: .Text.secondary,
        isLoading: true
      )
    case .noConnection:
      return ConnectionStatusView.Model(
        title: TKLocales.ConnectionStatus.no_internet,
        titleColor: .Accent.orange,
        isLoading: false
      )
    }
  }
  
  func createHeaderButtonsModel(wallet: Wallet) -> WalletBalanceHeaderButtonsView.Model {
    let isSendEnable: Bool
    let isReceiveEnable: Bool
    let isScanEnable: Bool
    let isSwapEnable: Bool
    let isBuyEnable: Bool
    let isStakeEnable: Bool
    
    switch wallet.kind {
    case .regular:
      isSendEnable = true
      isReceiveEnable = true
      isScanEnable = true
      isSwapEnable = true
      isBuyEnable = true
      isStakeEnable = true
    case .lockup:
      isSendEnable = false
      isReceiveEnable = false
      isScanEnable = false
      isSwapEnable = false
      isBuyEnable = false
      isStakeEnable = false
    case .watchonly:
      isSendEnable = false
      isReceiveEnable = true
      isScanEnable = false
      isSwapEnable = false
      isBuyEnable = true
      isStakeEnable = false
    case .signer:
      isSendEnable = true
      isReceiveEnable = true
      isScanEnable = true
      isSwapEnable = true
      isBuyEnable = true
      isStakeEnable = true
    case .ledger:
      isSendEnable = true
      isReceiveEnable = true
      isScanEnable = true
      isSwapEnable = true
      isBuyEnable = true
      isStakeEnable = false
    }
    
    return WalletBalanceHeaderButtonsView.Model(
      sendButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.send,
        icon: .TKUIKit.Icons.Size28.arrowUpOutline,
        isEnabled: isSendEnable,
        action: { [weak self] in self?.didTapSend?() }
      ),
      recieveButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.receive,
        icon: .TKUIKit.Icons.Size28.arrowDownOutline,
        isEnabled: isReceiveEnable,
        action: { [weak self] in self?.didTapReceive?() }
      ),
      scanButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.scan,
        icon: .TKUIKit.Icons.Size28.qrViewFinderThin,
        isEnabled: isScanEnable,
        action: { [weak self] in self?.didTapScan?() }
      ),
      swapButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.swap,
        icon: .TKUIKit.Icons.Size28.swapHorizontalOutline,
        isEnabled: isSwapEnable,
        action: { [weak self] in
          self?.didTapSwap?()
        }
      ),
      buyButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.buy,
        icon: .TKUIKit.Icons.Size28.usd,
        isEnabled: isBuyEnable,
        action: { [weak self] in
          self?.didTapBuy?(wallet)
        }
      ),
      stakeButton: WalletBalanceHeaderButtonsView.Model.Button(
        title: TKLocales.WalletButtons.stake,
        icon: .TKUIKit.Icons.Size28.stakingOutline,
        isEnabled: isStakeEnable,
        action: { [weak self] in
          self?.didTapStake?(wallet)
        }
      )
    )
  }
  
  func didTapCopy(address: String, toastConfiguration: ToastPresenter.Configuration) {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    UIPasteboard.general.string = address

    didCopy?(toastConfiguration)
  }
}

private extension String {
  static let manageButtonCellIdentifier = "ManageButtonCellIdentifier"
}

private extension Int64 {
  static let tonAmountWarning: Int64 = 2000000000
  static let tonAmountError: Int64 = 20000000000
}

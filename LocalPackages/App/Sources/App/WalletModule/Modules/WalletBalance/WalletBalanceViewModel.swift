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

  var didTapReceive: (() -> Void)? { get set }
  var didTapSend: (() -> Void)? { get set }
  var didTapScan: (() -> Void)? { get set }
  var didTapBuy: ((Wallet) -> Void)? { get set }
  var didTapSwap: (() -> Void)? { get set }
  
  var didTapBackup: ((Wallet) -> Void)? { get set }
  var didRequirePasscode: (() async -> String?)? { get set }
}

protocol WalletBalanceModuleInput: AnyObject {}

protocol WalletBalanceViewModel: AnyObject {
  var didUpdateSnapshot: ((_ snapshot: WalletBalanceViewController.Snapshot, _ isAnimated: Bool) -> Void)? { get set }
  
  var didUpdateItems: (([WalletBalanceItem: WalletBalanceListCell.Model]) -> Void)? { get set }
  
  var didChangeWallet: (() -> Void)? { get set }
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)? { get set }
  var didCopy: ((ToastPresenter.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapFinishSetupButton()
  func getBalanceItemCellModel(item: WalletBalanceItem) -> WalletBalanceListCell.Model?
  func didSelectItem(_ item: WalletBalanceItem)
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput, WalletBalanceModuleInput {
  
  private struct State {
    let balanceItems: WalletBalanceBalanceModel.BalanceListItems
    let setupState: WalletBalanceSetupModel.State
  }
  
  // MARK: - WalletBalanceModuleOutput
  
  var didUpdateSnapshot: ((_ snapshot: WalletBalanceViewController.Snapshot, _ isAnimated: Bool) -> Void)?
  
  var didUpdateItems: (([WalletBalanceItem: WalletBalanceListCell.Model]) -> Void)?
  
  var didSelectTon: ((Wallet) -> Void)?
  var didSelectJetton: ((Wallet, JettonItem, Bool) -> Void)?
  
  var didTapReceive: (() -> Void)?
  var didTapSend: (() -> Void)?
  var didTapScan: (() -> Void)?
  var didTapBuy: ((Wallet) -> Void)?
  var didTapSwap: (() -> Void)?
  
  var didTapBackup: ((Wallet) -> Void)?
  var didRequirePasscode: (() async -> String?)?
  
  // MARK: - WalletBalanceViewModel
  
  var didChangeWallet: (() -> Void)?
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)?
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
  }
  
  func getBalanceItemCellModel(item: WalletBalanceItem) -> WalletBalanceListCell.Model? {
    return cellModels[item]
  }
  
  func didTapFinishSetupButton() {
    setupModel.finishSetup()
  }
  
  func didSelectItem(_ item: WalletBalanceItem) {
    cellModels[item]?.selectionClosure?()
  }
  
  // MARK: - State

  private let actor = SerialActor()
  private var state = State(
    balanceItems: WalletBalanceBalanceModel.BalanceListItems(
      tonItem: nil, usdtItem: nil, jettonsItems: [], stakingItems: []
    ),
    setupState: .none)
  private var cellModels = [WalletBalanceItem: WalletBalanceListCell.Model]()
  private var stakingUpdateTimer: DispatchSourceTimer?

  // MARK: - Mapper
  
  // MARK: - Dependencies
  
  private let balanceListModel: WalletBalanceBalanceModel
  private let setupModel: WalletBalanceSetupModel
  private let totalBalanceModel: WalletTotalBalanceModel
  private let walletsStore: WalletsStoreV2
  private let listMapper: WalletBalanceListMapper
  private let headerMapper: WalletBalanceHeaderMapper
  private let secureMode: SecureMode
  
  init(balanceListModel: WalletBalanceBalanceModel,
       setupModel: WalletBalanceSetupModel,
       totalBalanceModel: WalletTotalBalanceModel,
       walletsStore: WalletsStoreV2,
       listMapper: WalletBalanceListMapper,
       headerMapper: WalletBalanceHeaderMapper,
       secureMode : SecureMode) {
    self.balanceListModel = balanceListModel
    self.setupModel = setupModel
    self.totalBalanceModel = totalBalanceModel
    self.walletsStore = walletsStore
    self.listMapper = listMapper
    self.headerMapper = headerMapper
    self.secureMode = secureMode
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
        
        let secureState: WalletBalanceHeaderBalanceButton.State = state.isSecure ? .secure : .unsecure
        
        let balanceModel = WalletBalanceHeaderBalanceView.Model(
          balanceButtonModel: WalletBalanceHeaderBalanceButton.Model(
            balance: totalBalanceMapped,
            state: secureState,
            tapHandler: { [weak self] in
              guard let self else { return }
              Task {
                await self.secureMode.toggle()
              }
            }
          ),
          addressButtonConfiguration: addressButtonConfiguration,
          connectionStatusModel: nil,
          tagConfiguration: state.wallet.balanceTagConfiguration(),
          stateDate: nil
        )
        
        let model = WalletBalanceHeaderView.Model(
          balanceModel: balanceModel,
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
        var models = [WalletBalanceItem: WalletBalanceListCell.Model]()
        
        if let tonItem = items.tonItem {
          models[WalletBalanceItem(id: tonItem.id)] = self.listMapper.mapTonItem(
            tonItem,
            isSecure: isSecure,
            selectionHandler: { [weak self] in
              self?.didSelectTon?(wallet)
            })
        }
        
        if let tonUSDTItem = items.usdtItem {
          models[WalletBalanceItem(id: tonUSDTItem.id)] = self.listMapper.mapJettonItem(
            tonUSDTItem,
            isSecure: isSecure,
            selectionHandler: { [weak self] in
              self?.didSelectJetton?(wallet, tonUSDTItem.jetton, !tonUSDTItem.price.isZero)
            })
        }
        
        items.stakingItems.forEach { item in
          models[WalletBalanceItem(id: item.id)] = self.listMapper.mapStakingItem(
            item,
            isSecure: isSecure,
            selectionHandler: {
              print("Open staking")
            },
            stakingCollectHandler: {
              print("Collect")
            })
        }
        
        if !items.stakingItems.isEmpty {
          self.startStakingItemsUpdateTimer(stakingItems: items.stakingItems)
        }
        
        items.jettonsItems.forEach { item in
          models[WalletBalanceItem(id: item.id)] = self.listMapper.mapJettonItem(
            item,
            isSecure: isSecure) { [weak self] in
              self?.didSelectJetton?(wallet, item.jetton, !item.price.isZero)
            }
        }

        let state = State(balanceItems: items,
                          setupState: self.state.setupState)
        let snapshot = self.createSnapshot(state: state)
        
        self.state = state
        await MainActor.run { [snapshot, models] in
          self.cellModels.merge(models) { $1 }
          self.didUpdateSnapshot?(snapshot, false)
        }
      })
    }
  }
  
  func didUpdateSetupState(_ state: WalletBalanceSetupModel.State) {
    Task {
      await self.actor.addTask(block: {
        let models = self.listMapper.mapSetupState(
          state,
          biometrySelectionHandler: {
            
          },
          telegramChannelSelectionHandler: {
            
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
                          setupState: state)
        let snapshot = self.createSnapshot(state: state)
        self.state = state
        await MainActor.run { [snapshot] in
          self.cellModels.merge(models) { $1 }
          self.didUpdateSnapshot?(snapshot, false)
        }
      })
    }
  }
  
  private func createSnapshot(state: State) -> WalletBalanceViewController.Snapshot {
    var snapshot = WalletBalanceViewController.Snapshot()
    
    switch state.setupState {
    case .setup(let setup):
      let items: [WalletBalanceItem] = {
        var items = [WalletBalanceItem]()
        if setup.isBiometryVisible {
          items.append(WalletBalanceItem(id: WalletBalanceSetupItem.biometry.rawValue))
        }
        if setup.isTelegramChannelVisible {
          items.append(WalletBalanceItem(id: WalletBalanceSetupItem.telegramChannel.rawValue))
        }
        if setup.isBackupVisible {
          items.append(WalletBalanceItem(id: WalletBalanceSetupItem.backup.rawValue))
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
    if let tonItem = state.balanceItems.tonItem {
      items.append(WalletBalanceItem(id: tonItem.id))
    }
    if let usdtItem = state.balanceItems.usdtItem {
      items.append(WalletBalanceItem(id: usdtItem.id))
    }
    items.append(contentsOf: state.balanceItems.stakingItems.map { WalletBalanceItem(id: $0.id) })
    items.append(contentsOf: state.balanceItems.jettonsItems.map { WalletBalanceItem(id: $0.id) })

    snapshot.appendSections([.balance])
    snapshot.appendItems(items, toSection: .balance)
    
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    
    return snapshot
  }

  func updateBalanceHeader(wallet: Wallet, totalBalanceState: TotalBalanceState?) {
    guard let address = try? wallet.friendlyAddress else { return }
  
    let totalBalance = totalBalanceState?.totalBalance
    
    let totalBalanceMapped = headerMapper.mapTotalBalance(totalBalance: totalBalance)
    
    let addressButtonConfiguration = TKButton.Configuration(
      content: TKButton.Configuration.Content(title: .plainString(address.toShort())),
      textStyle: .body2,
      textColor: .Text.secondary,
      contentAlpha: [.normal: 1, .highlighted: 0.48],
      action: { [weak self] in
        self?.didTapCopy(address: address.toString(), toastConfiguration: wallet.copyToastConfiguration())
      }
    )
    
    let balanceModel = WalletBalanceHeaderBalanceView.Model(
      balanceButtonModel: WalletBalanceHeaderBalanceButton.Model(
        balance: totalBalanceMapped,
        state: .secure,
        tapHandler: { [weak self] in
          guard let self else { return }
          Task {
            await self.secureMode.toggle()
          }
        }
      ),
      addressButtonConfiguration: addressButtonConfiguration,
      connectionStatusModel: nil,
      tagConfiguration: wallet.balanceTagConfiguration(),
      stateDate: nil
    )
    
    let model = WalletBalanceHeaderView.Model(
      balanceModel: balanceModel,
      buttonsViewModel: createHeaderButtonsModel(wallet: wallet)
    )
    
    DispatchQueue.main.async {
      self.didUpdateHeader?(model)
    }
  }
  
  func startStakingItemsUpdateTimer(stakingItems: [WalletBalanceBalanceModel.BalanceListStakingItem]) {
    let queue = DispatchQueue(label: "WalletBalanceStakingItemsTimerQueue", qos: .background)
    let timer: DispatchSourceTimer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
    timer.schedule(deadline: .now(), repeating: 1, leeway: .milliseconds(100))
    timer.resume()
    timer.setEventHandler(handler: { [weak self] in
      self?.updateStakingItemsOnTimer(stakingItems: stakingItems)
    })
    self.stakingUpdateTimer = timer
  }
  
  func stopStakingItemsUpdateTimer() {
    self.stakingUpdateTimer?.cancel()
    self.stakingUpdateTimer = nil
  }
  
  func updateStakingItemsOnTimer(stakingItems: [WalletBalanceBalanceModel.BalanceListStakingItem]) {
    Task {
      await self.actor.addTask(block: {
        var models = [WalletBalanceItem: WalletBalanceListCell.Model]()
        let isSecure = await self.secureMode.isSecure
        stakingItems.forEach { item in
          models[WalletBalanceItem(id: item.id)] = self.listMapper.mapStakingItem(
            item,
            isSecure: isSecure,
            selectionHandler: {
              print("Open staking")
            },
            stakingCollectHandler: {
              print("Collect")
            })
        }
        
        await MainActor.run { [models] in
          self.cellModels.merge(models) { $1 }
          self.didUpdateItems?(models)
        }
      })
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
      isStakeEnable = false
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
      isStakeEnable = false
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
        action: {}
      )
    )
  }
  
  func didTapCopy(address: String, toastConfiguration: ToastPresenter.Configuration) {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
    UIPasteboard.general.string = address

    didCopy?(toastConfiguration)
  }
}

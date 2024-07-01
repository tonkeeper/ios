import Foundation
import TKUIKit
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
  
  var didChangeWallet: (() -> Void)? { get set }
  var didUpdateHeader: ((WalletBalanceHeaderView.Model) -> Void)? { get set }
  var didCopy: ((ToastPresenter.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapFinishSetupButton()
  func getBalanceItemCellModel(item: WalletBalanceItem) -> TKUIListItemCell.Configuration?
  func didSelectItem(_ item: WalletBalanceItem)
}

final class WalletBalanceViewModelImplementation: WalletBalanceViewModel, WalletBalanceModuleOutput, WalletBalanceModuleInput {
  
  private struct State {
    let balanceItems: [WalletBalanceBalanceModel.BalanceListItem]
    let setupState: WalletBalanceSetupModel.State
  }
  
  // MARK: - WalletBalanceModuleOutput
  
  var didUpdateSnapshot: ((_ snapshot: WalletBalanceViewController.Snapshot, _ isAnimated: Bool) -> Void)?
  
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
    balanceListModel.didUpdateItems = { [weak self] items in
      self?.didUpdateBalanceItems(items)
    }
    setupModel.didUpdateState = { [weak self] state in
      self?.didUpdateSetupState(state)
    }
    
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, walletsState, oldWalletsState in
      observer.didUpdateWalletsState(walletsState, oldWalletsState)
    }
    totalBalanceStore.addObserver(self, notifyOnAdded: true) { observer, state, oldState in
      observer.didUpdateTotalBalanceState(state, oldState)
    }
  }
  
  func getBalanceItemCellModel(item: WalletBalanceItem) -> TKUIListItemCell.Configuration? {
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
  private var state = State(balanceItems: [], setupState: .none)
  private var cellModels = [WalletBalanceItem: TKUIListItemCell.Configuration]()

  // MARK: - Mapper
  
  // MARK: - Dependencies
  
  private let balanceListModel: WalletBalanceBalanceModel
  private let setupModel: WalletBalanceSetupModel
  private let walletsStore: WalletsStoreV2
  private let totalBalanceStore: TotalBalanceStoreV2
  private let listMapper: WalletBalanceListMapper
  private let headerMapper: WalletBalanceHeaderMapper
  
  init(balanceListModel: WalletBalanceBalanceModel,
       setupModel: WalletBalanceSetupModel,
       walletsStore: WalletsStoreV2,
       totalBalanceStore: TotalBalanceStoreV2,
       listMapper: WalletBalanceListMapper,
       headerMapper: WalletBalanceHeaderMapper) {
    self.balanceListModel = balanceListModel
    self.setupModel = setupModel
    self.walletsStore = walletsStore
    self.totalBalanceStore = totalBalanceStore
    self.listMapper = listMapper
    self.headerMapper = headerMapper
  }
}

private extension WalletBalanceViewModelImplementation {
  func didUpdateWalletsState(_ walletsState: WalletsState,
                             _ oldWalletsState: WalletsState?) {
    Task {
      guard walletsState.activeWallet != oldWalletsState?.activeWallet else { return }
      guard let address = try? walletsState.activeWallet.friendlyAddress else { return }
      let totalBalanceState = await self.totalBalanceStore.getState()[address]
      updateBalanceHeader(wallet: walletsState.activeWallet, totalBalanceState: totalBalanceState)
    }
  }
  
  func didUpdateTotalBalanceState(_ totalBalances: [FriendlyAddress: TotalBalanceState],
                                  _ oldTotalBalances: [FriendlyAddress: TotalBalanceState]?) {
    Task {
      let wallet = await walletsStore.getState().activeWallet
      guard let address = try? wallet.friendlyAddress else { return }
      guard totalBalances[address] != oldTotalBalances?[address] else { return }
      updateBalanceHeader(wallet: wallet, totalBalanceState: totalBalances[address])
    }
  }
  
  func didUpdateBalanceItems(_ items: [WalletBalanceBalanceModel.BalanceListItem]) {
    Task {
      await self.actor.addTask(block: {
        let wallet = await self.walletsStore.getState().activeWallet
        let models = items.reduce([WalletBalanceItem: TKUIListItemCell.Configuration]()) { result, item in
          var result = result
          result[WalletBalanceItem(id: item.id)] = self.listMapper.mapItem(item, selectionHandler: {
            switch item.type {
            case .ton:
              self.didSelectTon?(wallet)
            case .jetton(let jettonItem):
              self.didSelectJetton?(wallet, jettonItem, !item.price.isZero)
            }
          })
          return result
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
    
    let items = state.balanceItems.map { WalletBalanceItem(id: $0.id) }

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
      balance: totalBalanceMapped,
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

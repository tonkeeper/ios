import Foundation
import KeeperCore

struct WalletsListModelState {
  let wallets: [Wallet]
  let selectedWallet: Wallet?
}

protocol WalletsListModel: AnyObject {
  var isEditable: Bool { get }
  var didUpdateWalletsState: ((WalletsListModelState) -> Void)? { get set }
  
  func getWalletsState() -> WalletsListModelState
  func selectWallet(wallet: Wallet)
  func moveWallet(fromIndex: Int, toIndex: Int)
}

final class WalletsPickerListModel: WalletsListModel {
  private let walletsStore: WalletsStore
  private let walletsUpdater: WalletsStoreUpdater
  
  init(walletsStore: WalletsStore, 
       walletsUpdater: WalletsStoreUpdater) {
    self.walletsStore = walletsStore
    self.walletsUpdater = walletsUpdater
    walletsStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      let state = WalletsListModelState(
        wallets: newState.wallets,
        selectedWallet: newState.activeWallet
      )
      observer.didUpdateWalletsState?(state)
    }
  }
  
  var isEditable: Bool {
    true
  }
  
  var didUpdateWalletsState: ((WalletsListModelState) -> Void)?
  
  func getWalletsState() -> WalletsListModelState {
    let storeState = walletsStore.getState()
    return WalletsListModelState(
      wallets: storeState.wallets,
      selectedWallet: storeState.activeWallet
    )
  }
  
  func selectWallet(wallet: Wallet) {
    Task {
      await walletsUpdater.setWalletActive(wallet)
    }
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) {
    Task {
      await walletsUpdater.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
    }
  }
}

final class TonConnectWalletsPickerListModel: WalletsListModel {
  
  var didSelectWallet: ((Wallet) -> Void)?
  
  private let walletsStore: WalletsStore
  
  init(walletsStore: WalletsStore) {
    self.walletsStore = walletsStore
  }
  
  var isEditable: Bool {
    false
  }
  
  var didUpdateWalletsState: ((WalletsListModelState) -> Void)?
  
  func getWalletsState() -> WalletsListModelState {
    let storeState = walletsStore.getState()
    let wallets = storeState.wallets.filter { $0.isTonconnectAvailable }
    guard let activeWallet = (wallets.first(where: { $0 == storeState.activeWallet }) ?? wallets.first) else {
      return WalletsListModelState(wallets: wallets, selectedWallet: nil)
    }
    return WalletsListModelState(wallets: wallets, selectedWallet: activeWallet)
  }
  
  func selectWallet(wallet: Wallet) {
    DispatchQueue.main.async {
      self.didSelectWallet?(wallet)
    }
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) {}
}

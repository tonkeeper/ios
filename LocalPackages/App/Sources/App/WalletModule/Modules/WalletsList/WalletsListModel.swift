import Foundation
import KeeperCore

protocol WalletsListModel: AnyObject {
  var isEditable: Bool { get }
  var didUpdateWalletsState: ((WalletsState) -> Void)? { get set }
  
  func setInitialState()
  func selectWallet(wallet: Wallet)
  func moveWallet(fromIndex: Int, toIndex: Int)
}

final class WalletsPickerListModel: WalletsListModel {
  private let walletsStore: WalletsStoreV2
  private let walletsUpdater: WalletsStoreUpdater
  
  init(walletsStore: WalletsStoreV2, 
       walletsUpdater: WalletsStoreUpdater) {
    self.walletsStore = walletsStore
    self.walletsUpdater = walletsUpdater
  }
  
  var isEditable: Bool {
    true
  }
  
  var didUpdateWalletsState: ((KeeperCore.WalletsState) -> Void)?
  
  func setInitialState() {
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, walletsState, _ in
      observer.didUpdateWalletsState?(walletsState)
    }
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
  
  private let walletsStore: WalletsStoreV2
  
  init(walletsStore: WalletsStoreV2) {
    self.walletsStore = walletsStore
  }
  
  var isEditable: Bool {
    false
  }
  
  var didUpdateWalletsState: ((KeeperCore.WalletsState) -> Void)?
  
  func setInitialState() {
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, walletsState, _ in
      let wallets = walletsState.wallets.filter { $0.isTonconnectAvailable }
      guard !wallets.isEmpty else { return }
      guard let activeWallet = (wallets.first(where: { $0 == walletsState.activeWallet }) ?? wallets.first) else {
        return
      }
      let state = WalletsState(wallets: wallets, activeWallet: activeWallet)
      observer.didUpdateWalletsState?(state)
    }
  }
  
  func selectWallet(wallet: Wallet) {
    DispatchQueue.main.async {
      self.didSelectWallet?(wallet)
    }
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) {}
}

import Foundation

protocol WalletListControllerConfigurator: AnyObject {
  var didUpdateWallets: (() -> Void)? { get set }
  var didUpdateSelectedWallet: (() -> Void)? { get set }
  
  var isEditable: Bool { get }
  
  func getWallets() -> [Wallet]
  func getSelectedWallet() -> Wallet?
  func getSelectedWalletIndex() -> Int?
  func selectWallet(at index: Int)
  func moveWallet(fromIndex: Int, toIndex: Int) throws
}

extension WalletListControllerConfigurator {
  func getSelectedWallet() -> Wallet? { return nil }
}

final class WalletStoreWalletListControllerConfigurator: WalletListControllerConfigurator {
  
  var didUpdateWallets: (() -> Void)?
  var didUpdateSelectedWallet: (() -> Void)?
  
  var isEditable: Bool {
    true
  }
  
  func getWallets() -> [Wallet] {
    walletsStore.wallets
  }
  
  func getSelectedWallet() -> Wallet? {
    walletsStore.activeWallet
  }
  
  func getSelectedWalletIndex() -> Int? {
    walletsStore.wallets.firstIndex(where: { $0.identity == walletsStore.activeWallet.identity })
  }
  
  func selectWallet(at index: Int) {
    guard index < walletsStore.wallets.count else { return }
    guard walletsStore.wallets[index] != walletsStore.activeWallet else { return }
    do {
      try walletsStoreUpdate.makeWalletActive(walletsStore.wallets[index])
    } catch {
      didUpdateSelectedWallet?()
    }
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) throws {
    try walletsStoreUpdate.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
  }
  
  private let walletsStore: WalletsStore
  private let walletsStoreUpdate: WalletsStoreUpdate
  
  init(walletsStore: WalletsStore, walletsStoreUpdate: WalletsStoreUpdate) {
    self.walletsStore = walletsStore
    self.walletsStoreUpdate = walletsStoreUpdate
    
    _ = walletsStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateActiveWallet:
        observer.didUpdateSelectedWallet?()
      case .didUpdateWalletsOrder:
        observer.didUpdateWallets?()
      case .didAddWallets:
        observer.didUpdateWallets?()
      case .didUpdateWalletMetadata:
        observer.didUpdateWallets?()
      default:
        break
      }
    }
  }
}

final class WalletSelectWalletListControllerConfigurator: WalletListControllerConfigurator {
  
  var didSelectWallet: ((Wallet) -> Void)?
  
  var didUpdateWallets: (() -> Void)?
  var didUpdateSelectedWallet: (() -> Void)?
  
  var isEditable: Bool {
    false
  }
  
  func getWallets() -> [Wallet] {
    walletsStore.wallets.filter { $0.isRegular || $0.isTestnet }
  }
  
  func getSelectedWalletIndex() -> Int? {
    walletsStore.wallets.firstIndex(where: { $0.identity == selectedWallet.identity })
  }
  
  func selectWallet(at index: Int) {
    guard index < walletsStore.wallets.count else { return }
    let selectedWallet = walletsStore.wallets[index]
    Task { @MainActor in
      didSelectWallet?(selectedWallet)
    }
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) throws {}
  
  private let selectedWallet: Wallet
  private let walletsStore: WalletsStore
  
  init(selectedWallet: Wallet, walletsStore: WalletsStore) {
    self.selectedWallet = selectedWallet
    self.walletsStore = walletsStore
    
    _ = walletsStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateWalletsOrder:
        observer.didUpdateWallets?()
      case .didAddWallets:
        observer.didUpdateWallets?()
      case .didUpdateWalletMetadata:
        observer.didUpdateWallets?()
      default:
        break
      }
    }
  }
}

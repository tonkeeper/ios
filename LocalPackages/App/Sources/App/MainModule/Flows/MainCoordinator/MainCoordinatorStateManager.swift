import Foundation
import KeeperCore

final class MainCoordinatorStateManager {
  
  struct State: Equatable {
    enum Tab: Equatable {
      case wallet
      case history
      case browser
      case purchases
    }
    
    let tabs: [Tab]
  }
  
  var didUpdateState: ((State) -> Void)?
  
  private var walletNFTsManagedStore: WalletNFTsManagedStore?
  
  private let walletsStore: WalletsStore
  private let walletNFTsManagedStoreProvider: (Wallet) -> WalletNFTsManagedStore
  
  init(walletsStore: WalletsStore,
       walletNFTsManagedStoreProvider: @escaping (Wallet) -> WalletNFTsManagedStore) {
    self.walletsStore = walletsStore
    self.walletNFTsManagedStoreProvider = walletNFTsManagedStoreProvider
    
    updateWalletNFTsManagedStore()
    
    walletsStore.addObserver(self) { observer, event in
      switch event {
      case .didChangeActiveWallet:
        DispatchQueue.main.async {
          observer.updateWalletNFTsManagedStore()
          observer.updateState()
        }
      default: break
      }
    }
  }
  
  func getState() throws -> State {
    let wallet = try walletsStore.getActiveWallet()
    
    let nfts = walletNFTsManagedStore?.getState() ?? []
    let state = createState(activeWallet: wallet, nfts: nfts)
    return state
  }

  private func createState(activeWallet: Wallet, nfts: [NFT]) -> State {
    var tabs = [State.Tab]()
    tabs.append(.wallet)
    tabs.append(.history)
    if activeWallet.isBrowserAvailable {
      tabs.append(.browser)
    }
    if !nfts.isEmpty {
      tabs.append(.purchases)
    }
    
    let state = State(tabs: tabs)
    return state
  }
  
  private func updateState() {
    guard let state = try? getState() else { return }
    didUpdateState?(state)
  }
  
  private func updateWalletNFTsManagedStore() {
    if let wallet = try? walletsStore.getActiveWallet() {
      self.walletNFTsManagedStore = walletNFTsManagedStoreProvider(wallet)
      self.walletNFTsManagedStore?.addObserver(self, closure: { observer, event in
        DispatchQueue.main.async {
          observer.updateState()
        }
      })
    } else {
      self.walletNFTsManagedStore = nil
    }
  }
}

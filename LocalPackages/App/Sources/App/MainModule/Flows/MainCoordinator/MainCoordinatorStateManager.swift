import Foundation
import KeeperCore
import TKFeatureFlags

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
  
  private var walletNFTsStore: WalletNFTStore?
  
  private let walletsStore: WalletsStore
  private let walletNFTStoreProvider: (Wallet) -> WalletNFTStore
  
  init(walletsStore: WalletsStore,
       walletNFTStoreProvider: @escaping (Wallet) -> WalletNFTStore) {
    self.walletsStore = walletsStore
    self.walletNFTStoreProvider = walletNFTStoreProvider
    
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
    let wallet = try walletsStore.activeWallet
    
    let nfts = walletNFTsStore?.state.value.nfts.visible ?? []
    let state = createState(activeWallet: wallet, nfts: nfts)
    return state
  }

  private func createState(activeWallet: Wallet, nfts: [NFT]) -> State {
    var tabs = [State.Tab]()
    tabs.append(.wallet)
    tabs.append(.history)
    tabs.append(.browser)
    if !TKFeatureFlags.provider.isPurchasesHiddenIfEmpty || !nfts.isEmpty {
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
    if let wallet = try? walletsStore.activeWallet {
      self.walletNFTsStore = walletNFTStoreProvider(wallet)
      Task { await self.walletNFTsStore?.addObserver(self) }
    } else {
      self.walletNFTsStore = nil
    }
  }
}

extension MainCoordinatorStateManager: WalletNFTStoreObserver {
  func didUpdateNFTs(_ nfts: WalletNFTs) {
    Task { @MainActor in updateState() }
  }
}

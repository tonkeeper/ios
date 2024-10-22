import Foundation

public final class WalletNFTsManagedStore: Store<WalletNFTsManagedStore.Event, WalletNFTsManagedStore.State> {
  public typealias State = [NFT]
  public enum Event {
    case didUpdateNFTs(wallet: Wallet)
  }
  
  private let wallet: Wallet
  private let walletNFTStore: WalletNFTStore
  private let walletNFTsManagementStore: WalletNFTsManagementStore
  
  init(wallet: Wallet,
       walletNFTStore: WalletNFTStore,
       walletNFTsManagementStore: WalletNFTsManagementStore) {
    self.wallet = wallet
    self.walletNFTStore = walletNFTStore
    self.walletNFTsManagementStore = walletNFTsManagementStore
    super.init(state: [])
    
    walletNFTStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateNFTs(let wallet):
        guard wallet == observer.wallet else { return }
        observer.update()
      }
    }
    
    walletNFTsManagementStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateState(let wallet):
        guard wallet == observer.wallet else { return }
        observer.update()
      }
    }
  }
  
  public override func createInitialState() -> State {
    calculateState()
  }
  
  private func update() {
    updateState { [weak self] state in
      guard let self else { return nil }
      return StateUpdate(newState: calculateState())
    } completion: { [weak self] _ in
      guard let self else { return }
      sendEvent(.didUpdateNFTs(wallet: wallet))
    }
  }
  
  private func calculateState() -> State {
    let managementStoreState = walletNFTsManagementStore.state
    let nfts = walletNFTStore.state[wallet] ?? []
    return nfts.filter { nft in
      let state: NFTsManagementState.NFTState?
      if let collection = nft.collection {
        state = managementStoreState.nftStates[.collection(collection.address)]
      } else {
        state = managementStoreState.nftStates[.singleItem(nft.address)]
      }
      
      switch nft.trust {
      case .blacklist:
        return state == .visible
      case .graylist, .none, .unknown, .whitelist:
        return state != .hidden
      }
    }
  }
}

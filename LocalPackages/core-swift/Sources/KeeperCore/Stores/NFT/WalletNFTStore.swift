import Foundation
import TonSwift

public final class WalletNFTStore: Store<WalletNFTStore.Event, WalletNFTStore.State> {
  public typealias State = [Wallet: [NFT]]
  public enum Event {
    case didUpdateNFTs(wallet: Wallet)
  }
  
  private let walletsStore: WalletsStore
  private let nftStore: NFTStore
  private let repository: WalletNFTRepository
  
  init(walletsStore: WalletsStore,
       nftStore: NFTStore,
       repository: WalletNFTRepository) {
    self.walletsStore = walletsStore
    self.nftStore = nftStore
    self.repository = repository
    super.init(state: [:])
    
    walletsStore.addObserver(self) { observer, event in
      Task {
        switch event {
        case .didAddWallets(let wallets):
          await observer.didAddWallets(wallets)
        default: break
        }
      }
    }
    
    nftStore.addObserver(self) { observer, event in
      Task {
        switch event {
        case .didUpdateNFT(let nft):
          await observer.didUpdateNFT(nft)
        }
      }
    }
  }
  
  public override func createInitialState() -> State {
    let wallets = walletsStore.wallets
    var state = State()
    wallets.forEach { wallet in
      let nfts = repository.getNFTs(wallet: wallet)
      state[wallet] = nfts
    }
    return state
  }
  
  public func setNFTs(_ nfts: [NFT], wallet: Wallet) async {
    await setState { state in
      var updatedState = state
      updatedState[wallet] = nfts
      
      try? self.repository.saveNFTs(nfts, wallet: wallet)
      
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      self.sendEvent(.didUpdateNFTs(wallet: wallet))
    }
  }
  
  private func didAddWallets(_ wallets: [Wallet]) async {
    var observersActions = [(() -> Void)]()
    await setState { [repository] state in
      var updatedState = state
      wallets.forEach { wallet in
        guard state[wallet] == nil else { return }
        let nfts = repository.getNFTs(wallet: wallet)
        updatedState[wallet] = nfts
        observersActions.append({
          self.sendEvent(.didUpdateNFTs(wallet: wallet))
        })
      }
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      observersActions.forEach { $0() }
    }
  }
  
  private func didUpdateNFT(_ nft: NFT) async {
    var observersActions = [(() -> Void)]()
    await setState { state in
      var updatedState = state
      for (wallet, nfts) in state {
        guard let index = nfts.firstIndex(of: nft) else { continue }
        var nfts = nfts
        nfts.remove(at: index)
        nfts.insert(nft, at: index)
        updatedState[wallet] = nfts
        observersActions.append({
          self.sendEvent(.didUpdateNFTs(wallet: wallet))
        })
      }
      return StateUpdate(newState: updatedState)
    } notify: { _ in
      observersActions.forEach { $0() }
    }
  }
}

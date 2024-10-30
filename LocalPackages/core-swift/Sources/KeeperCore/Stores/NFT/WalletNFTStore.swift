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
      switch event {
      case .didAddWallets(let wallets):
        observer.updateState(wallets: wallets) { [weak observer] in
          wallets.forEach { observer?.sendEvent(.didUpdateNFTs(wallet: $0)) }
        }
      default: break
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
    return await withCheckedContinuation { continuation in
      setNFTs(nfts, wallet: wallet) {
        continuation.resume()
      }
    }
  }
  
  public func setNFTs(_ nfts: [NFT], wallet: Wallet, completion: @escaping () -> Void) {
    updateState { state in
      var updatedState = state
      updatedState[wallet] = nfts
      try? self.repository.saveNFTs(nfts, wallet: wallet)
      return StateUpdate(newState: updatedState)
    } completion: { [weak self] _ in
      self?.sendEvent(.didUpdateNFTs(wallet: wallet))
      completion()
    }
  }
  
  private func updateState(wallets: [Wallet], completion: @escaping () -> Void) {
    updateState { [weak self] state in
      guard let self else { return nil }
      var updatedState = state
      wallets.forEach { wallet in
        guard state[wallet] == nil else { return }
        let nfts = self.repository.getNFTs(wallet: wallet)
        updatedState[wallet] = nfts
      }
      return StateUpdate(newState: updatedState)
    } completion: { _ in
      completion()
    }
  }
}

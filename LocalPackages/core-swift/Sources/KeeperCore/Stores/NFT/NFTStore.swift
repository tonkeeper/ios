import Foundation
import TonSwift

public final class NFTStore: Store<NFTStore.Event, NFTStore.State> {
  public typealias State = Void
  public enum Event {
    case didUpdateNFT(nft: NFT)
  }
  
  private let repository: NFTRepository
  
  init(repository: NFTRepository) {
    self.repository = repository
    super.init(state: Void())
  }
  
  public override func createInitialState() -> State {
    Void()
  }
  
  public func setNFT(_ nft: NFT) async {
    await withCheckedContinuation { continuation in
      setNFT(nft) {
        continuation.resume()
      }
    }
  }
  
  public func setNFT(_ nft: NFT, completion: (() -> Void)?) {
    updateState { [repository] _  in
      try? repository.saveNFT(nft, key: nft.address.toRaw())
      return StateUpdate(newState: Void())
    } completion: { [weak self] _ in
      self?.sendEvent(.didUpdateNFT(nft: nft))
    }
  }
}

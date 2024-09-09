import Foundation
import TonSwift

public final class NFTStore: StoreV3<NFTStore.Event, NFTStore.State> {
  public typealias State = Void
  public enum Event {
    case didUpdateNFT(nft: NFT)
  }
  
  private let repository: NFTRepository
  
  init(repository: NFTRepository) {
    self.repository = repository
    super.init(state: Void())
  }
  
  public override var initialState: State {
    Void()
  }
  
  public func setNFT(_ nft: NFT) async {
    await setState { [repository] _ in
      try? repository.saveNFT(nft, key: nft.address.toRaw())
      return StateUpdate(newState: Void())
    } notify: { _ in
      self.sendEvent(.didUpdateNFT(nft: nft))
    }
  }
}

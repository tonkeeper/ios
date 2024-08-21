import Foundation
import TonSwift

public final class AccountNFTsStore: StoreUpdated<[FriendlyAddress: AccountNFTsStore.State]> {
  public enum State: Equatable {
    case loading(cached: [NFT])
    case items(item: [NFT])
  }
  
  private let walletsStore: WalletsStore
  private let repository: AccountNFTRepository
  
  init(walletsStore: WalletsStore, 
       repository: AccountNFTRepository) {
    self.walletsStore = walletsStore
    self.repository = repository
    super.init(state: [:])
  }
  
  public override func getState() -> [FriendlyAddress : State] {
    return super.getState()
  }
  
  public func setLoading(address: FriendlyAddress,
                         completion: (() -> Void)?) {
    updateState { [repository] state in
      let items: [NFT] = {
        do {
          return try repository.getNfts(key: address.toString())
        } catch {
          return []
        }
      }()
      var updatedState = state
      updatedState[address] = .loading(cached: items)
      return StateUpdate(newState: updatedState)
    } completion: {
      completion?()
    }
  }
  
  public func setLoading(address: FriendlyAddress) async {
    await updateState { [repository] state in
      let items: [NFT] = {
        do {
          return try repository.getNfts(key: address.toString())
        } catch {
          return []
        }
      }()
      var updatedState = state
      updatedState[address] = .loading(cached: items)
      return StateUpdate(newState: updatedState)
    }
  }
  
  public func setNFTS(_ nfts: [NFT],
                      address: FriendlyAddress,
                      completion: (() -> Void)?) {
    updateState { [repository] state in
      try? repository.saveNfts(nfts, key: address.toString())
      var updatedState = state
      updatedState[address] = .items(item: nfts)
      return StateUpdate(newState: updatedState)
    } completion: {
      completion?()
    }
  }

  public func setNFTS(_ nfts: [NFT],
                      address: FriendlyAddress) async {
    await updateState { [repository] state in
      try? repository.saveNfts(nfts, key: address.toString())
      var updatedState = state
      updatedState[address] = .items(item: nfts)
      return StateUpdate(newState: updatedState)
    }
  }

  public override func getInitialState() -> [FriendlyAddress : State] {
    let wallets = walletsStore.getState().wallets
    let addresses = wallets.compactMap { try? $0.friendlyAddress }
    var state = [FriendlyAddress: State]()
    addresses.forEach { address in
      do {
        let items = try repository.getNfts(key: address.toString())
        state[address] = .items(item: items)
      } catch {
        state[address] = .items(item: [])
      }
    }
    return state
  }
}

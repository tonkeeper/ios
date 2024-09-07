//import Foundation
//import TonSwift
//
//public final class AccountNFTsStore: StoreUpdated<[FriendlyAddress: [NFT]]> {
//  private let walletsStore: WalletsStore
//  private let repository: AccountNFTRepository
//  
//  init(walletsStore: WalletsStore, 
//       repository: AccountNFTRepository) {
//    self.walletsStore = walletsStore
//    self.repository = repository
//    super.init(state: [:])
//  }
//  
//  public func setNFTS(_ nfts: [NFT],
//                      address: FriendlyAddress,
//                      completion: (() -> Void)?) {
//    updateState { [repository] state in
//      try? repository.saveNfts(nfts, key: address.toString())
//      var updatedState = state
//      updatedState[address] = nfts
//      return StateUpdate(newState: updatedState)
//    } completion: {
//      completion?()
//    }
//  }
//
//  public func setNFTS(_ nfts: [NFT],
//                      address: FriendlyAddress) async {
//    await updateState { [repository] state in
//      try? repository.saveNfts(nfts, key: address.toString())
//      var updatedState = state
//      updatedState[address] = nfts
//      return StateUpdate(newState: updatedState)
//    }
//  }
//
//  public override func getInitialState() -> [FriendlyAddress: [NFT]] {
//    let wallets = walletsStore.getState().wallets
//    let addresses = wallets.compactMap { try? $0.friendlyAddress }
//    var state = [FriendlyAddress: [NFT]]()
//    addresses.forEach { address in
//      do {
//        let items = try repository.getNfts(key: address.toString())
//        state[address] = items
//      } catch {
//        state[address] = []
//      }
//    }
//    return state
//  }
//}

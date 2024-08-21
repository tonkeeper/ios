import Foundation
import TonSwift

public actor AccountNftsLoader {
  private var tasksInProgress = [FriendlyAddress: Task<(), Never>]()
  
  private let accountNFTsStore: AccountNFTsStore
  private let nftsService: AccountNFTService
  
  init(accountNFTsStore: AccountNFTsStore, nftsService: AccountNFTService) {
    self.accountNFTsStore = accountNFTsStore
    self.nftsService = nftsService
  }

  public func loadNfts(wallet: Wallet) {
    guard let address = try? wallet.friendlyAddress else { return }
    if let taskInProgress = tasksInProgress[address] {
      taskInProgress.cancel()
      tasksInProgress[address] = nil
    }
    
    let task = Task {
      defer {
        tasksInProgress[address] = nil
      }
      do {
        await accountNFTsStore.setLoading(address: address)
        let nfts = try await nftsService.loadAccountNFTs(
          wallet: wallet,
          collectionAddress: nil,
          limit: nil,
          offset: nil,
          isIndirectOwnership: true
        )
        guard !Task.isCancelled else { return }
        await accountNFTsStore.setNFTS(nfts, address: address)
      } catch {
        guard !error.isCancelledError else { return }
        tasksInProgress[address] = nil
        await accountNFTsStore.setNFTS([], address: address)
      }
    }
    tasksInProgress[address] = task
  }
}

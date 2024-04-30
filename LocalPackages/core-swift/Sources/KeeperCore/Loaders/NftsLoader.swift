import Foundation
import TonSwift

actor NftsLoader {
  private var tasksInProgress = [Address: Task<(), Never>]()
  
  private let nftsStore: NftsStore
  private let nftsService: AccountNFTService
  
  init(nftsStore: NftsStore, nftsService: AccountNFTService) {
    self.nftsStore = nftsStore
    self.nftsService = nftsService
  }
  
  func loadNfts(address: Address) {
    if let taskInProgress = tasksInProgress[address] {
      taskInProgress.cancel()
      tasksInProgress[address] = nil
    }
    
    let task = Task {
      do {
        let nfts = try await nftsService.loadAccountNFTs(
          accountAddress: address,
          collectionAddress: nil,
          limit: nil,
          offset: nil,
          isIndirectOwnership: true
        )
        guard !Task.isCancelled else { return }
        await nftsStore.setNfts(nfts, walletAddress: address)
      } catch {
        guard !error.isCancelledError else { return }
        await nftsStore.setNfts([], walletAddress: address)
      }
    }
    tasksInProgress[address] = task
  }
}

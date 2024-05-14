import Foundation
import TonSwift

actor NftsLoader {
  private var tasksInProgress = [FriendlyAddress: Task<(), Never>]()
  
  private let nftsStore: NftsStore
  private let nftsService: AccountNFTService
  
  init(nftsStore: NftsStore, nftsService: AccountNFTService) {
    self.nftsStore = nftsStore
    self.nftsService = nftsService
  }
  
  func loadNfts(wallet: Wallet) {
    guard let address = try? wallet.friendlyAddress else { return }
    if let taskInProgress = tasksInProgress[address] {
      taskInProgress.cancel()
      tasksInProgress[address] = nil
    }
    
    let task = Task {
      do {
        let nfts = try await nftsService.loadAccountNFTs(
          wallet: wallet,
          collectionAddress: nil,
          limit: nil,
          offset: nil,
          isIndirectOwnership: true
        )
        guard !Task.isCancelled else { return }
        await nftsStore.setNfts(nfts, wallet: wallet)
      } catch {
        guard !error.isCancelledError else { return }
        await nftsStore.setNfts([], wallet: wallet)
      }
    }
    tasksInProgress[address] = task
  }
}

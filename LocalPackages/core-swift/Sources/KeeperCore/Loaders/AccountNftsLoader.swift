//import Foundation
//import TonSwift
//
//public actor AccountNftsLoader {
//  private var tasksInProgress = [FriendlyAddress: Task<[NFT], Swift.Error>]()
//  
//  private let accountNFTsStore: AccountNFTsStore
//  private let nftsService: AccountNFTService
//  
//  init(accountNFTsStore: AccountNFTsStore, nftsService: AccountNFTService) {
//    self.accountNFTsStore = accountNFTsStore
//    self.nftsService = nftsService
//  }
//
//  public func loadNfts(wallet: Wallet) async throws -> [NFT] {
//    guard let address = try? wallet.friendlyAddress else { return [] }
//    if let taskInProgress = tasksInProgress[address] {
//      return try await taskInProgress.value
//    }
//    
//    let task = Task {
//      let nfts = try await self.nftsService.loadAccountNFTs(
//        wallet: wallet,
//        collectionAddress: nil,
//        limit: nil,
//        offset: nil,
//        isIndirectOwnership: true
//      )
//      try Task.checkCancellation()
//      return nfts
//    }
//    tasksInProgress[address] = task
//    return try await task.value
//  }
//}

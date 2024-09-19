import Foundation
import TonSwift

public struct AccountNfts {
  let wallet: Wallet
  let nfts: [NFT]
}

public protocol AccountNFTService {
  func getAccountNfts(wallet: Wallet) -> [NFT]
  func getAccountsNfts(wallets: [Wallet]) -> [AccountNfts]
  func loadAccountNFTs(wallet: Wallet,
                       collectionAddress: Address?,
                       limit: Int?,
                       offset: Int?,
                       isIndirectOwnership: Bool) async throws -> [NFT]
  func loadAccountsNfts(wallets: [Wallet],
                        collectionAddress: Address?,
                        limit: Int,
                        offset: Int,
                        isIndirectOwnership: Bool) async throws -> [AccountNfts]
  func saveAccountNfts(wallet: Wallet,
                       nfts: [NFT]) throws
}

final class AccountNFTServiceImplementation: AccountNFTService {
  private let apiProvider: APIProvider
  private let accountNFTRepository: AccountNFTRepository
  private let nftRepository: NFTRepository
  
  init(apiProvider: APIProvider, accountNFTRepository: AccountNFTRepository, nftRepository: NFTRepository) {
    self.apiProvider = apiProvider
    self.accountNFTRepository = accountNFTRepository
    self.nftRepository = nftRepository
  }
  
  func getAccountNfts(wallet: Wallet) -> [NFT] {
    do {
      return try accountNFTRepository.getNfts(key: wallet.friendlyAddress.toShort())
    } catch {
      return []
    }
  }
  
  func getAccountsNfts(wallets: [Wallet]) -> [AccountNfts] {
    wallets.compactMap {
      let nfts = getAccountNfts(wallet: $0)
      return AccountNfts(wallet: $0, nfts: nfts)
    }
  }
  
  func loadAccountNFTs(wallet: Wallet,
                       collectionAddress: Address?,
                       limit: Int?,
                       offset: Int?,
                       isIndirectOwnership: Bool) async throws -> [NFT] {
    do {
      let nfts = try await apiProvider.api(wallet.isTestnet).getAccountNftItems(
        address: wallet.address,
        collectionAddress: collectionAddress,
        limit: limit,
        offset: offset,
        isIndirectOwnership: isIndirectOwnership
      )
      nfts.forEach {
        try? nftRepository.saveNFT($0, key: $0.address.toRaw())
      }
      try? accountNFTRepository.saveNfts(nfts, key: wallet.friendlyAddress.toShort())
      return nfts
    } catch {
      try? accountNFTRepository.saveNfts([], key: wallet.friendlyAddress.toShort())
      throw error
    }
  }
  
  func loadAccountsNfts(wallets: [Wallet],
                        collectionAddress: Address?,
                        limit: Int,
                        offset: Int,
                        isIndirectOwnership: Bool) async throws -> [AccountNfts] {
    let nfts = await withTaskGroup(of: AccountNfts.self, returning: [AccountNfts].self) { [weak self] taskGroup in
      guard let self = self else { return [] }
      for wallet in wallets {
        taskGroup.addTask {
          do {
            let nfts = try await self.loadAccountNFTs(
              wallet: wallet,
              collectionAddress: nil,
              limit: limit,
              offset: offset,
              isIndirectOwnership: true
            )
            return AccountNfts(wallet: wallet, nfts: nfts)
          } catch {
            return AccountNfts(wallet: wallet, nfts: [])
          }
        }
      }
      return await taskGroup.reduce(into: [AccountNfts]()) { partialResult, accountNfts in
        partialResult.append(accountNfts)
      }
    }
    return nfts
  }
  
  func saveAccountNfts(wallet: Wallet,
                       nfts: [NFT]) throws {
    try accountNFTRepository.saveNfts(
      nfts,
      key: wallet.friendlyAddress.toString()
    )
  }
}

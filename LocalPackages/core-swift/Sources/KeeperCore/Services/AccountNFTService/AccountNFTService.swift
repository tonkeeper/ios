import Foundation
import TonSwift

struct AccountNfts {
  let address: Address
  let nfts: [NFT]
}

protocol AccountNFTService {
  func getAccountNfts(accountAddress: Address) -> [NFT]
  func getAccountsNfts(accountAddresses: [Address]) -> [AccountNfts]
  func loadAccountNFTs(accountAddress: Address,
                       collectionAddress: Address?,
                       limit: Int?,
                       offset: Int?,
                       isIndirectOwnership: Bool) async throws -> [NFT]
  func loadAccountsNfts(accountAddresses: [Address],
                        collectionAddress: Address?,
                        limit: Int,
                        offset: Int,
                        isIndirectOwnership: Bool) async throws -> [AccountNfts]
  func saveAccountNfts(accountAddress: Address,
                       nfts: [NFT]) throws
}

final class AccountNFTServiceImplementation: AccountNFTService {
  private let api: API
  private let accountNFTRepository: AccountNFTRepository
  private let nftRepository: NFTRepository
  
  init(api: API, accountNFTRepository: AccountNFTRepository, nftRepository: NFTRepository) {
    self.api = api
    self.accountNFTRepository = accountNFTRepository
    self.nftRepository = nftRepository
  }
  
  func getAccountNfts(accountAddress: Address) -> [NFT] {
    do {
      return try accountNFTRepository.getNfts(key: accountAddress.toRaw())
    } catch {
      return []
    }
  }
  
  func getAccountsNfts(accountAddresses: [Address]) -> [AccountNfts] {
    accountAddresses.compactMap {
      let nfts = getAccountNfts(accountAddress: $0)
      return AccountNfts(address: $0, nfts: nfts)
    }
  }
  
  func loadAccountNFTs(accountAddress: Address,
                       collectionAddress: Address?,
                       limit: Int?,
                       offset: Int?,
                       isIndirectOwnership: Bool) async throws -> [NFT] {
    do {
      let nfts = try await api.getAccountNftItems(
        address: accountAddress,
        collectionAddress: collectionAddress,
        limit: limit,
        offset: offset,
        isIndirectOwnership: isIndirectOwnership
      )
      nfts.forEach {
        try? nftRepository.saveNFT($0, key: $0.address.toRaw())
      }
      try? accountNFTRepository.saveNfts(nfts, key: accountAddress.toRaw())
      return nfts
    } catch {
      try? accountNFTRepository.saveNfts([], key: accountAddress.toRaw())
      throw error
    }
  }
  
  func loadAccountsNfts(accountAddresses: [Address],
                        collectionAddress: Address?,
                        limit: Int,
                        offset: Int,
                        isIndirectOwnership: Bool) async throws -> [AccountNfts] {
    let nfts = await withTaskGroup(of: AccountNfts.self, returning: [AccountNfts].self) { [weak self] taskGroup in
      guard let self = self else { return [] }
      for address in accountAddresses {
        taskGroup.addTask {
          do {
            let nfts = try await self.loadAccountNFTs(
              accountAddress: address,
              collectionAddress: nil,
              limit: limit,
              offset: offset,
              isIndirectOwnership: true
            )
            return AccountNfts(address: address, nfts: nfts)
          } catch {
            return AccountNfts(address: address, nfts: [])
          }
        }
      }
      return await taskGroup.reduce(into: [AccountNfts]()) { partialResult, accountNfts in
        partialResult.append(accountNfts)
      }
    }
    return nfts
  }
  
  func saveAccountNfts(accountAddress: Address,
                       nfts: [NFT]) throws {
    try accountNFTRepository.saveNfts(
      nfts,
      key: accountAddress.toRaw()
    )
  }
}

import Foundation
import TonSwift

protocol NFTService {
  func loadNFTs(addresses: [Address]) async throws -> [Address: NFT]
  func getNFTs() throws -> [Address: NFT]
  func getNFT(address: Address) throws -> NFT
  func saveNFT(nft: NFT) throws
}

final class NFTServiceImplementation: NFTService {
  private let api: API
  private let nftRepository: NFTRepository
  
  init(api: API, nftRepository: NFTRepository) {
    self.api = api
    self.nftRepository = nftRepository
  }
  
  func loadNFTs(addresses: [Address]) async throws -> [Address: NFT] {
    let nfts = try await api.getNftItemsByAddresses(addresses)
    var result = [Address: NFT]()
    nfts.forEach {
      try? nftRepository.saveNFT($0, key: $0.address.toRaw())
      result[$0.address] = $0
    }
    return result
  }
  
  func getNFTs() throws -> [Address: NFT] {
    let nfts = nftRepository.getNFTs()
    var result = [Address: NFT]()
    nfts.forEach {
      result[$0.address] = $0
    }
    return result
  }
  
  func getNFT(address: Address) throws -> NFT {
    try nftRepository.getNFT(address.toRaw())
  }
  
  func saveNFT(nft: NFT) throws {
    try nftRepository.saveNFT(nft, key: nft.address.toRaw())
  }
}

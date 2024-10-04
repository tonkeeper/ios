import Foundation
import TonSwift

public protocol NFTService {
  func loadNFTs(addresses: [Address], isTestnet: Bool) async throws -> [Address: NFT]
  func getNFT(address: Address, isTestnet: Bool) throws -> NFT
  func saveNFT(nft: NFT, isTestnet: Bool) throws
}

final class NFTServiceImplementation: NFTService {
  private let apiProvider: APIProvider
  private let nftRepository: NFTRepository
  
  init(apiProvider: APIProvider, nftRepository: NFTRepository) {
    self.apiProvider = apiProvider
    self.nftRepository = nftRepository
  }
  
  func loadNFTs(addresses: [Address], isTestnet: Bool) async throws -> [Address: NFT] {
    let nfts = try await apiProvider.api(isTestnet).getNftItemsByAddresses(addresses)
    var result = [Address: NFT]()
    nfts.forEach {
      try? nftRepository.saveNFT(
        $0,
        key: FriendlyAddress(address: $0.address, testOnly: isTestnet, bounceable: true).toShort()
      )
      result[$0.address] = $0
    }
    return result
  }

  func getNFT(address: Address, isTestnet: Bool) throws -> NFT {
    try nftRepository.getNFT(
      FriendlyAddress(address: address, testOnly: isTestnet, bounceable: true).toShort()
    )
  }
  
  func saveNFT(nft: NFT, isTestnet: Bool) throws {
    try nftRepository.saveNFT(
      nft,
      key: FriendlyAddress(address: nft.address, testOnly: isTestnet, bounceable: true).toShort()
    )
  }
}

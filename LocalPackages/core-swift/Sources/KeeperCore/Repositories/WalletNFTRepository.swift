import Foundation
import TonSwift
import CoreComponents

public protocol WalletNFTRepository {
  func saveNFTs(_ nfts: [NFT], wallet: Wallet) throws
  func getNFTs(wallet: Wallet) -> [NFT]
}

struct WalletNFTRepositoryImplementation: WalletNFTRepository {
  private let fileSystemVault: FileSystemVault<[Address], String>
  private let nftRepository: NFTRepository
  
  
  init(fileSystemVault: FileSystemVault<[Address], String>,
       nftRepository: NFTRepository) {
    self.fileSystemVault = fileSystemVault
    self.nftRepository = nftRepository
  }
  
  func saveNFTs(_ nfts: [NFT], wallet: Wallet) throws {
    let key = try wallet.friendlyAddress.toString()
    var addresses = [Address]()
    for nft in nfts {
      try nftRepository.saveNFT(nft, key: nft.address.toRaw())
      addresses.append(nft.address)
    }
    try fileSystemVault.saveItem(addresses, key: key)
  }
  
  func getNFTs(wallet: Wallet) -> [NFT] {
    do {
      let addresses = try fileSystemVault.loadItem(key: wallet.friendlyAddress.toString())
      let nfts = addresses.compactMap {
        try? nftRepository.getNFT($0.toRaw())
      }
      return nfts
    } catch {
      return []
    }
  }
}

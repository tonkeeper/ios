import Foundation
import TonSwift
import CoreComponents

protocol NFTRepository {
  func saveNFT(_ nft: NFT, key: String) throws
  func getNFT(_ key: String) throws -> NFT
  func getNFTs() -> [NFT]
}

struct NFTRepositoryImplementation: NFTRepository {
  let fileSystemVault: FileSystemVault<NFT, String>
  
  init(fileSystemVault: FileSystemVault<NFT, String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveNFT(_ nft: NFT, key: String) throws {
    try fileSystemVault.saveItem(nft, key: key)
  }
  
  func getNFT(_ key: String) throws -> NFT {
    return try fileSystemVault.loadItem(key: key)
  }
  
  func getNFTs() -> [NFT] {
    return fileSystemVault.loadAll()
  }
}

import Foundation
import TonSwift
import CoreComponents

protocol AccountNFTRepository {
  func saveNfts(_ nfts: [NFT], key: String) throws
  func getNfts(key: String) throws -> [NFT]
}

struct AccountNFTRepositoryImplementation: AccountNFTRepository {
  let fileSystemVault: FileSystemVault<[NFT], String>
  
  init(fileSystemVault: FileSystemVault<[NFT], String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveNfts(_ nfts: [NFT], key: String) throws {
    try fileSystemVault.saveItem(nfts, key: key)
  }
  
  func getNfts(key: String) throws -> [NFT] {
    try fileSystemVault.loadItem(key: key)
  }
}

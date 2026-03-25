import CoreComponents
import Foundation
import TonSwift

protocol NFTRepository {
    func saveNFT(_ nft: NFT, key: String) throws
    func getNFT(_ key: String) throws -> NFT
}

struct NFTRepositoryImplementation: NFTRepository {
    let fileSystemVault: FileSystemVault<NFT, String>

    func saveNFT(_ nft: NFT, key: String) throws {
        try fileSystemVault.saveItem(nft, key: key)
    }

    func getNFT(_ key: String) throws -> NFT {
        return try fileSystemVault.loadItem(key: key)
    }
}

import CoreComponents
import Foundation
import TonSwift

protocol AccountNFTRepository {
    func saveNfts(_ nfts: [NFT], key: String) throws
}

struct AccountNFTRepositoryImplementation: AccountNFTRepository {
    let fileSystemVault: FileSystemVault<[NFT], String>

    func saveNfts(_ nfts: [NFT], key: String) throws {
        try fileSystemVault.saveItem(nfts, key: key)
    }
}

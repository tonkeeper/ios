import CoreComponents
import Foundation
import TonSwift

public protocol WalletNFTsRepository {
    func get(wallet: Wallet) -> WalletNFTs
    func save(nfts: WalletNFTs, wallet: Wallet) throws
}

struct WalletNFTsRepositoryImplementation: WalletNFTsRepository {
    private let fileSystemVault: FileSystemVault<WalletNFTs, String>

    init(fileSystemVault: FileSystemVault<WalletNFTs, String>) {
        self.fileSystemVault = fileSystemVault
    }

    func get(wallet: Wallet) -> WalletNFTs {
        do {
            let key = try wallet.friendlyAddress.toString()
            return try fileSystemVault.loadItem(key: key)
        } catch {
            return WalletNFTs(
                all: [],
                visible: [],
                hidden: [],
                spam: [],
                blacklistedCount: 0
            )
        }
    }

    func save(nfts: WalletNFTs, wallet: Wallet) throws {
        let key = try wallet.friendlyAddress.toString()
        try fileSystemVault.saveItem(nfts, key: key)
    }
}

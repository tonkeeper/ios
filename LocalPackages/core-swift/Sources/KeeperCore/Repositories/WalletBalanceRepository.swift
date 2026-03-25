import CoreComponents
import Foundation
import TonSwift

protocol WalletBalanceRepositoryV2 {
    func getBalance(address: FriendlyAddress) throws -> WalletBalance
}

struct WalletBalanceRepositoryV2implementation: WalletBalanceRepositoryV2 {
    let fileSystemVault: FileSystemVault<WalletBalance, FriendlyAddress>

    func getBalance(address: FriendlyAddress) throws -> WalletBalance {
        try fileSystemVault.loadItem(key: address)
    }
}

protocol WalletBalanceRepository {
    func getWalletBalance(wallet: Wallet) throws -> WalletBalance
    func saveWalletBalance(_ walletBalance: WalletBalance, for wallet: Wallet) throws
}

struct WalletBalanceRepositoryImplementation: WalletBalanceRepository {
    let fileSystemVault: FileSystemVault<WalletBalance, FriendlyAddress>

    func getWalletBalance(wallet: Wallet) throws -> WalletBalance {
        try fileSystemVault.loadItem(key: wallet.friendlyAddress)
    }

    func saveWalletBalance(
        _ walletBalance: WalletBalance,
        for wallet: Wallet
    ) throws {
        try fileSystemVault.saveItem(walletBalance, key: wallet.friendlyAddress)
    }
}

extension FriendlyAddress: @retroactive CustomStringConvertible {
    public var description: String {
        toString()
    }
}

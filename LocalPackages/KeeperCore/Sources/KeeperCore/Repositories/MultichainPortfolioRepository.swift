import Foundation
import KeeperCoreComponents

protocol MultichainPortfolioRepository {
    func getPortfolioTotal(walletId: String) throws -> MultichainPortfolioTotal
    func savePortfolioTotal(_ total: MultichainPortfolioTotal, walletId: String) throws
}

struct MultichainPortfolioRepositoryImplementation: MultichainPortfolioRepository {
    let fileSystemVault: FileSystemVault<MultichainPortfolioTotal, String>

    func getPortfolioTotal(walletId: String) throws -> MultichainPortfolioTotal {
        try fileSystemVault.loadItem(key: walletId)
    }

    func savePortfolioTotal(_ total: MultichainPortfolioTotal, walletId: String) throws {
        try fileSystemVault.saveItem(total, key: walletId)
    }
}

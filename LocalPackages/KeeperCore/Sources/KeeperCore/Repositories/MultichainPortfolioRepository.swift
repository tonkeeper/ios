import Foundation
import KeeperCoreComponents

protocol MultichainPortfolioRepository {
    func getPortfolio(walletId: String) throws -> MultichainPortfolio
    func savePortfolio(_ portfolio: MultichainPortfolio, walletId: String) throws
}

struct MultichainPortfolioRepositoryImplementation: MultichainPortfolioRepository {
    let fileSystemVault: FileSystemVault<MultichainPortfolio, String>

    func getPortfolio(walletId: String) throws -> MultichainPortfolio {
        try fileSystemVault.loadItem(key: walletId)
    }

    func savePortfolio(_ portfolio: MultichainPortfolio, walletId: String) throws {
        try fileSystemVault.saveItem(portfolio, key: walletId)
    }
}

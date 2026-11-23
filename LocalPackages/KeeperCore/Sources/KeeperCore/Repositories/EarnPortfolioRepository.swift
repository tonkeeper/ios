import Foundation
import KeeperCoreComponents
import TKLogging

struct EarnPortfolioRepository {
    private let fileSystemVault: FileSystemVault<EarnPortfolio, String>

    init(fileSystemVault: FileSystemVault<EarnPortfolio, String>) {
        self.fileSystemVault = fileSystemVault
    }

    func portfolio(walletId: String) -> EarnPortfolio? {
        do {
            return try fileSystemVault.loadItem(key: walletId)
        } catch FileSystemVault<EarnPortfolio, String>.LoadError.noItem {
            return nil
        } catch {
            Log.w("earn portfolio cache is unreadable", extraInfo: ["error": "\(error)"])
            return nil
        }
    }

    func savePortfolio(_ portfolio: EarnPortfolio, walletId: String) {
        do {
            try fileSystemVault.saveItem(portfolio, key: walletId)
        } catch {
            Log.w("earn portfolio cache write failed", extraInfo: ["error": "\(error)"])
        }
    }
}

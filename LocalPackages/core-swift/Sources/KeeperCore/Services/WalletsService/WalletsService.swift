import CoreComponents
import Foundation

enum WalletsServiceError: Swift.Error {
    case emptyWallets
    case walletNotAdded
    case incorrectMoveFromIndex
    case incorrectMoveToIndex
    case incorrectActiveWalletIdentity
}

public enum WalletsServiceDeleteWalletResult {
    case deletedWallet
    case deletedAll
}

public protocol WalletsService {
    func getWallets() throws -> [Wallet]
    func getActiveWallet() throws -> Wallet
}

final class WalletsServiceImplementation: WalletsService {
    let keeperInfoRepository: KeeperInfoRepository

    init(keeperInfoRepository: KeeperInfoRepository) {
        self.keeperInfoRepository = keeperInfoRepository
    }

    func getWallets() throws -> [Wallet] {
        try keeperInfoRepository.getKeeperInfo().wallets
    }

    func getActiveWallet() throws -> Wallet {
        let keeperInfo = try keeperInfoRepository.getKeeperInfo()
        return keeperInfo.currentWallet
    }
}

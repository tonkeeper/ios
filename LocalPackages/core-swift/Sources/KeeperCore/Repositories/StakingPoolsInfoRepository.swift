import CoreComponents
import Foundation
import TonSwift

protocol StakingPoolsInfoRepository {
    func getStakingPoolsInfo(wallet: Wallet) -> [StackingPoolInfo]
    func setStakingPoolsInfo(_ stakingPools: [StackingPoolInfo], wallet: Wallet) throws
}

struct StakingPoolsInfoRepositoryImplementation: StakingPoolsInfoRepository {
    let fileSystemVault: FileSystemVault<[StackingPoolInfo], FriendlyAddress>

    func getStakingPoolsInfo(wallet: Wallet) -> [StackingPoolInfo] {
        do {
            return try fileSystemVault.loadItem(key: wallet.friendlyAddress)
        } catch {
            return []
        }
    }

    func setStakingPoolsInfo(_ stakingPools: [StackingPoolInfo], wallet: Wallet) throws {
        try fileSystemVault.saveItem(stakingPools, key: wallet.friendlyAddress)
    }
}

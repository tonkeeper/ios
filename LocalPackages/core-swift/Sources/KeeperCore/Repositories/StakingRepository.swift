import Foundation
import TonSwift
import CoreComponents

protocol StakingRepository {
    func saveStakingPools(_ pools: [PoolImplementation]) throws
    func getStakingPools() throws -> [PoolImplementation]
}

struct StakingRepositoryImplementation: StakingRepository {
    let fileSystemVault: FileSystemVault<[PoolImplementation], String>
    
    init(fileSystemVault: FileSystemVault<[PoolImplementation], String>) {
        self.fileSystemVault = fileSystemVault
    }
    
    private static let vaultKey = String(describing: Self.self)
    
    func saveStakingPools(_ pools: [PoolImplementation]) throws {
        try fileSystemVault.saveItem(pools, key: Self.vaultKey)
    }
    
    func getStakingPools() throws -> [PoolImplementation] {
        let pools = try fileSystemVault.loadItem(key: Self.vaultKey)
        return pools
    }
}

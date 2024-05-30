import TonSwift

protocol StakingService {
    func getStakingNominatorPools(address: Address) async throws -> [AccountStakingInfo]
    func getStakingPools() -> [PoolImplementation]
    func loadStakingPools() async throws -> [PoolImplementation]
}

final class StakingServiceImplementation: StakingService {
    private let api: API
    private let stakingRepository: StakingRepository
    
    init(api: API, stakingRepository: StakingRepository) {
        self.api = api
        self.stakingRepository = stakingRepository
    }
    
    func getStakingNominatorPools(address: Address) async throws -> [AccountStakingInfo] {
        return try await api.getStakingNominatorPools(address: address)
    }
    
    func getStakingPools() -> [PoolImplementation] {
        do {
            return try stakingRepository.getStakingPools()
        } catch {
            return []
        }
    }
    
    func loadStakingPools() async throws -> [PoolImplementation] {
        let pools = try await api.getStakingPools()
        try? stakingRepository.saveStakingPools(pools)
        return pools
    }
}

import TonSwift

public final class StakingOptionsController {
    private let stakingService: StakingService
    private let wallet: Wallet
    
    public var didUpdateModel: (([PoolImplementation]) -> Void)?
    
    init(
        stakingService: StakingService,
        wallet: Wallet
    ) {
        self.stakingService = stakingService
        self.wallet = wallet
    }
    
    public func start() {
        didUpdateModel?(stakingService.getStakingPools())
        Task { [weak self] in
            guard let self else { return }
            do {                
                let availablePools = try await self.stakingService.loadStakingPools()
                self.didUpdateModel?(availablePools)
            } catch {
                print(error)
            }
        }
    }
}

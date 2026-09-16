import Foundation
import KeeperCore
import TKCore

struct StakingDepositInputAPYAssembly {
    private init() {}

    static func module(
        wallet: Wallet,
        stakingPool: StackingPoolInfo,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    )
        -> MVVMModule<StakingDepositInputAPYViewController, Void, StakingDepositInputAPYModuleInput>
    {
        let viewController = StakingDepositInputAPYViewController(
            wallet: wallet,
            stakingPool: stakingPool,
            balanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        return MVVMModule(view: viewController, output: (), input: viewController)
    }
}

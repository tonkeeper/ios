import Foundation
import KeeperCore
import TKCore

struct StakingDepositInputPoolPickerAssembly {
    private init() {}

    static func module(
        wallet: Wallet,
        selectedStakingPool: StackingPoolInfo?,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    )
        -> MVVMModule<StakingDepositInputPoolPickerViewController, StakingDepositInputPoolPickerModuleOutput, StakingDepositInputPoolPickerModuleInput>
    {
        let viewController = StakingDepositInputPoolPickerViewController(
            wallet: wallet,
            selectedStakingPool: selectedStakingPool,
            stakingPoolsStore: keeperCoreMainAssembly.storesAssembly.stackingPoolsStore,
            processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )

        return MVVMModule(view: viewController, output: viewController, input: viewController)
    }
}

import KeeperCore
import TKCore
import UIKit

struct BatteryRefillSupportedTransactionsAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> MVVMModule<BatteryRefillSupportedTransactionsViewController, BatteryRefillSupportedTransactionsModuleOutput, BatteryRefillSupportedTransactionsModuleInput> {
        let viewModel = BatteryRefillSupportedTransactionsViewModelImplementation(
            wallet: wallet,
            batteryChargeMapper: BatteryChargesMapper(batteryCalculation: keeperCoreMainAssembly.batteryAssembly.batteryCalculation)
        )

        let viewController = BatteryRefillSupportedTransactionsViewController(viewModel: viewModel)

        return MVVMModule(
            view: viewController,
            output: viewModel,
            input: viewModel
        )
    }
}

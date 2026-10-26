import KeeperCore
import TKCore
import UIKit

struct BatteryRefillTransactionsSettingsAssembly {
    private init() {}
    static func module(
        networks: BatteryNetworks,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> MVVMModule<BatteryRefillTransactionsSettingsViewController, BatteryRefillTransactionsSettingsModuleOutput, BatteryRefillTransactionsSettingsModuleInput> {
        let viewModel = BatteryRefillTransactionsSettingsViewModelImplementation(
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            keeperInfoStore: keeperCoreMainAssembly.storesAssembly.keeperInfoStore,
            networks: networks,
            batteryChargesMapper: BatteryChargesMapper(batteryCalculation: keeperCoreMainAssembly.batteryAssembly.batteryCalculation)
        )

        let viewController = BatteryRefillTransactionsSettingsViewController(viewModel: viewModel)

        return MVVMModule(
            view: viewController,
            output: viewModel,
            input: viewModel
        )
    }
}

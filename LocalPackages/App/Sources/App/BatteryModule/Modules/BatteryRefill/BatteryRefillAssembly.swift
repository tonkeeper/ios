import KeeperCore
import TKCore
import UIKit

struct BatteryRefillAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        promocodeStore: BatteryPromocodeStore,
        rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> MVVMModule<BatteryRefillHostingViewController, BatteryRefillModuleOutput, BatteryRefillModuleInput> {
        let promocodeViewModel = BatteryPromocodeInputAssembly.module(
            wallet: wallet,
            promocodeStore: promocodeStore,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        let viewModel = BatteryRefillViewModelImplementation(
            wallet: wallet,
            inAppPurchaseModel: BatteryRefillIAPModel(
                wallet: wallet,
                batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
                balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
                configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
                tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
                balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader
            ),
            rechargeMethodsModel: BatteryRefillRechargeMethodsModel(
                wallet: wallet,
                rechargeMethodsProvider: rechargeMethodsProvider,
                configuration: keeperCoreMainAssembly.configurationAssembly.configuration
            ),
            headerModel: BatteryRefillHeaderModel(
                wallet: wallet,
                balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
                batteryCalculation: keeperCoreMainAssembly.batteryAssembly.batteryCalculation
            ),
            tonProofTokenService: keeperCoreMainAssembly.servicesAssembly.tonProofTokenService(),
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            promocodeOutput: promocodeViewModel
        )

        viewModel.endPromocodeEditing = { [weak promocodeViewModel] in
            promocodeViewModel?.endEditing()
        }

        let viewController = BatteryRefillHostingViewController(
            viewModel: viewModel,
            promocodeViewModel: promocodeViewModel
        )

        return MVVMModule(
            view: viewController,
            output: viewModel,
            input: viewModel
        )
    }
}

import KeeperCore
import TKCore
import UIKit

struct BatteryRefillAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        promocodeStore: BatteryPromocodeStore,
        rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider,
        analytics: BatteryAnalytics,
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
            makeRechargeModel: { token in
                BatteryRechargeModel(
                    token: token,
                    wallet: wallet,
                    balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
                    currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
                    tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
                    ratesService: keeperCoreMainAssembly.servicesAssembly.ratesService(),
                    batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
                    configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
                    isGift: false
                )
            },
            balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            tonProofTokenService: keeperCoreMainAssembly.servicesAssembly.tonProofTokenService(),
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            promocodeOutput: promocodeViewModel,
            analytics: analytics,
            relayedEVMChains: keeperCoreMainAssembly.batteryRelayedEVMChains,
            batteryCalculation: keeperCoreMainAssembly.batteryAssembly.batteryCalculation
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

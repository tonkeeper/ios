import KeeperCore
import TKCore
import UIKit

struct BatteryRechargeAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        token: TonToken,
        isGift: Bool,
        selectsCustomAmount: Bool = false,
        initialOptionID: String? = nil,
        promocodeStore: BatteryPromocodeStore,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> MVVMModule<BatteryRechargeHostingViewController, BatteryRechargeModuleOutput, BatteryRechargeModuleInput> {
        let promocodeViewModel = BatteryPromocodeInputAssembly.module(
            wallet: wallet,
            promocodeStore: promocodeStore,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        let recipientViewModel = RecipientInputAssembly.module(
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        let amountInputViewModel = AmountInputAssembly.swiftUIModule(
            sourceUnit: token,
            destinationUnit: Currency.USD,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        let viewModel = BatteryRechargeViewModelImplementation(
            model: BatteryRechargeModel(
                token: token,
                wallet: wallet,
                balanceStore: keeperCoreMainAssembly.storesAssembly.balanceStore,
                currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
                tonRatesStore: keeperCoreMainAssembly.storesAssembly.tonRatesStore,
                ratesService: keeperCoreMainAssembly.servicesAssembly.ratesService(),
                batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
                configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
                isGift: isGift
            ),
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            isSecureMode: { [appSettingsStore = keeperCoreMainAssembly.storesAssembly.appSettingsStore] in appSettingsStore.getState().isSecureMode },
            amountInputModuleInput: amountInputViewModel,
            amountInputModuleOutput: amountInputViewModel,
            promocodeOutput: promocodeViewModel,
            recipientInputOutput: recipientViewModel,
            selectsCustomAmount: selectsCustomAmount,
            initialOptionID: initialOptionID
        )

        let viewController = BatteryRechargeHostingViewController(
            viewModel: viewModel,
            amountInputViewModel: amountInputViewModel,
            promocodeViewModel: promocodeViewModel,
            recipientViewModel: recipientViewModel
        )

        return MVVMModule(
            view: viewController,
            output: viewModel,
            input: viewModel
        )
    }
}

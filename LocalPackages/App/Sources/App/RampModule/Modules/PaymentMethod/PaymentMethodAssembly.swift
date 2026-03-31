import Foundation
import KeeperCore
import TKCore

struct PaymentMethodAssembly {
    private init() {}

    static func module(
        flow: RampFlow,
        asset: RampAsset,
        onRampLayout: OnRampLayout,
        isTRC20Available: Bool,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<PaymentMethodViewController, PaymentMethodModuleOutput, PaymentMethodModuleInput> {
        let onRampService = keeperCoreMainAssembly.servicesAssembly.onRampService()
        let currencyStore = keeperCoreMainAssembly.storesAssembly.currencyStore
        let currenciesService = keeperCoreMainAssembly.servicesAssembly.currenciesService()
        let viewModel = PaymentMethodViewModelImplementation(
            flow: flow,
            asset: asset,
            onRampLayout: onRampLayout,
            isTRC20Available: isTRC20Available,
            onRampService: onRampService,
            currencyStore: currencyStore,
            currenciesService: currenciesService
        )
        let viewController = PaymentMethodViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}

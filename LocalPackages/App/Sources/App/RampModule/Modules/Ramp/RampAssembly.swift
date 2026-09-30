import Foundation
import KeeperCore
import TKCore

struct RampAssembly {
    private init() {}

    static func module(
        flow: RampFlow,
        wallet: Wallet,
        keeperCoreAssembly: KeeperCore.MainAssembly,
        initialDeeplink: RampDeeplinkParameters? = nil
    ) -> MVVMModule<RampViewController, RampModuleOutput, RampModuleInput> {
        let onRampService = keeperCoreAssembly.servicesAssembly.onRampService()
        let viewModel = RampViewModelImplementation(
            flow: flow,
            wallet: wallet,
            onRampService: onRampService,
            currenciesService: keeperCoreAssembly.servicesAssembly.currenciesService(),
            currencyStore: keeperCoreAssembly.storesAssembly.currencyStore,
            initialDeeplink: initialDeeplink
        )

        let viewController = RampViewController(viewModel: viewModel)

        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}

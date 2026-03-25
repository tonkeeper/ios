import Foundation
import KeeperCore
import TKCore

struct RampAssembly {
    private init() {}

    static func module(
        flow: RampFlow,
        wallet: Wallet,
        keeperCoreAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<RampViewController, RampModuleOutput, RampModuleInput> {
        let onRampService = keeperCoreAssembly.servicesAssembly.onRampService()
        let viewModel = RampViewModelImplementation(
            flow: flow,
            wallet: wallet,
            configuration: keeperCoreAssembly.configurationAssembly.configuration,
            onRampService: onRampService
        )

        let viewController = RampViewController(viewModel: viewModel)

        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}

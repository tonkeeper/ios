import Foundation
import KeeperCore
import TKCore

@MainActor
struct DappSharingPopupAssembly {
    private init() {}
    static func module(
        dapp: Dapp,
        url: URL,
        keeperCoreAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<DappSharingPopupViewController, DappSharingPopupModuleOutput, Void> {
        let viewModel = DappSharingPopupViewModelImplementation(
            dapp: dapp, url: url
        )
        let viewController = DappSharingPopupViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}

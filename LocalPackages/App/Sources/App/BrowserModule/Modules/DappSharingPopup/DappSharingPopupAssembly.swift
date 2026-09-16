import Foundation
import KeeperCore
import TKCore

@MainActor
struct DappSharingPopupAssembly {
    private init() {}
    static func module(
        dapp: Dapp,
        url: URL,
        analyticsSession: DappOpenAnalyticsSession?
    ) -> MVVMModule<DappSharingPopupViewController, DappSharingPopupModuleOutput, Void> {
        let viewModel = DappSharingPopupViewModelImplementation(
            dapp: dapp,
            url: url,
            analyticsSession: analyticsSession
        )
        let viewController = DappSharingPopupViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}

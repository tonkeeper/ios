import Foundation
import KeeperCore
import TKCore

@MainActor
struct OpenDappWarningPopupAssembly {
    private init() {}
    static func module(
        url: URL,
        keeperCoreAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> MVVMModule<OpenDappWarningPopupViewController, OpenDappWarningPopupModuleOutput, Void> {
        let viewModel = OpenDappWarningPopupViewModelImplementation(
            url: url,
            appSettings: coreAssembly.appSettings
        )
        let viewController = OpenDappWarningPopupViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}

import Foundation
import KeeperCore
import TKCore

struct MultichainSendV3Assembly {
    private init() {}

    static func module(
        wallet: Wallet,
        sendInput: MultichainSendInput,
        recipient: MultichainRecipient?,
        comment: String?,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        autofocus: SendV3ViewController.Autofocus
    ) -> MVVMModule<SendV3ViewController, MultichainSendV3ModuleOutput, MultichainSendV3ModuleInput> {
        let viewModel = MultichainSendV3ViewModelImplementation(
            wallet: wallet,
            sendInput: sendInput,
            recipient: recipient,
            comment: comment,
            sendController: keeperCoreMainAssembly.sendV3Controller(wallet: wallet),
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore
        )
        let viewController = SendV3ViewController(
            viewModel: viewModel,
            autofocus: autofocus
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}

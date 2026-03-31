import Foundation
import KeeperCore
import TKCore

struct SendV3Assembly {
    private init() {}
    static func module(
        wallet: Wallet,
        sendInput: SendInput,
        recipient: Recipient?,
        comment: String?,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<SendV3ViewController, SendV3ModuleOutput, SendV3ModuleInput> {
        let viewModel = SendV3ViewModelImplementation(
            wallet: wallet,
            sendInput: sendInput,
            recipient: recipient,
            comment: comment,
            sendController: keeperCoreMainAssembly.sendV3Controller(wallet: wallet),
            balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            buySellMethodsService: keeperCoreMainAssembly.buySellAssembly.buySellMethodsService(),
            onRampService: keeperCoreMainAssembly.servicesAssembly.onRampService(),
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )
        let viewController = SendV3ViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}

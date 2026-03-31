import Foundation
import KeeperCore
import TKCore

struct ReceiveTabAssembly {
    private init() {}
    static func module(
        token: Token,
        wallet: Wallet,
        qrCodeGenerator: QRCodeGenerator,
        keeperCoreAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<ReceiveTabViewController, ReceiveTabModuleOutput, Void> {
        let viewModel = ReceiveTabViewModelImplementation(
            token: token,
            wallet: wallet,
            walletsStore: keeperCoreAssembly.storesAssembly.walletsStore,
            deeplinkGenerator: DeeplinkGenerator(),
            qrCodeGenerator: qrCodeGenerator,
            configuration: keeperCoreAssembly.configurationAssembly.configuration
        )
        let viewController = ReceiveTabViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}

import Foundation
import KeeperCore
import TKCore

public struct ReceiveAssembly {
    private init() {}
    public static func module(
        tokens: [Token],
        wallet: Wallet,
        keeperCoreAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<ReceiveViewController, ReceiveModuleOutput, ReceiveModuleInput> {
        let viewModel = ReceiveViewModelImplementation(
            tokens: tokens,
            wallet: wallet,
            walletsStore: keeperCoreAssembly.storesAssembly.walletsStore,
            tokenModuleViewControllerProvider: { receiveItem in
                ReceiveTabAssembly.module(
                    token: receiveItem,
                    wallet: wallet,
                    qrCodeGenerator: QRCodeGeneratorImplementation(),
                    keeperCoreAssembly: keeperCoreAssembly
                )
                .view
            }
        )
        let viewController = ReceiveViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}

import Foundation
import KeeperCore
import TKCore
import TKLogging
import TKUIKit

struct ReceiveTabAssembly {
    private init() {}
    static func module(
        token: ReceiveLegacyToken,
        wallet: Wallet,
        qrCodeGenerator: QrCodeMatrixGenerator,
        keeperCoreAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<ReceiveTabViewController, ReceiveTabModuleOutput, Void> {
        let viewModel = ReceiveTabViewModelImplementation(
            token: token,
            wallet: wallet,
            deeplinkGenerator: DeeplinkGenerator(),
            qrCodeGenerator: qrCodeGenerator
        )
        let viewController = ReceiveTabViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}

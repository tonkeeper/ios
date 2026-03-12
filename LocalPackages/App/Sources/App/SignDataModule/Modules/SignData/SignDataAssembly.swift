import Foundation
import KeeperCore
import TKCore
import UIKit

@MainActor
struct SignDataAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        dappUrl: String,
        signRequest: TonConnect.SignDataRequest,
        resultHandler: SignDataResultHandler,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<SignDataViewController, SignDataModuleOutput, SignDataModuleInput> {
        let viewModel = SignDataViewModelImplementation(
            wallet: wallet,
            dappUrl: dappUrl,
            signRequest: signRequest,
            resultHandler: resultHandler
        )

        let viewController = SignDataViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}

import Foundation
import KeeperCore
import TKCore

@MainActor
struct ReceiveTRC20PopupAssembly {
    private init() {}
    static func module(
        wallet: Wallet,
        keeperCoreAssembly: KeeperCore.MainAssembly,
        passcodeProvider: @escaping () async -> String?
    ) -> MVVMModule<ReceiveTRC20PopupViewController, ReceiveTRC20PopupModuleOutput, Void> {
        let viewModel = ReceiveTRC20PopupViewModelImplementation(
            wallet: wallet,
            tronWalletConfigurator: keeperCoreAssembly.tronUSDTAssembly.walletConfigurator(),
            passcodeProvider: passcodeProvider
        )
        let viewController = ReceiveTRC20PopupViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}

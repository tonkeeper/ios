import Foundation
import KeeperCore
import TKCore
import TonTransport

struct LedgerConfirmAssembly {
    private init() {}
    static func module(
        confirmItem: LedgerConfirmConfirmItem,
        wallet: Wallet,
        ledgerDevice: Wallet.LedgerDevice,
        coreAssembly: TKCore.CoreAssembly
    ) -> MVVMModule<LedgerConfirmViewController, LedgerConfirmModuleOutput, Void> {
        let viewModel = LedgerConfirmViewModelImplementation(
            confirmItem: confirmItem,
            wallet: wallet,
            ledgerDevice: ledgerDevice,
            bleTransport: coreAssembly.ledgerAssembly.bleTransport
        )
        let viewController = LedgerConfirmViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}

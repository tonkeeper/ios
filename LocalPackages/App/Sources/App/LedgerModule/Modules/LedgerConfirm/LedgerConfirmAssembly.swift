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
        coreAssembly: TKCore.CoreAssembly,
        knownJettonResolver: ((Transaction) -> KnownJetton?)? = nil
    ) -> MVVMModule<LedgerConfirmViewController, LedgerConfirmModuleOutput, Void> {
        let viewModel = LedgerConfirmViewModelImplementation(
            confirmItem: confirmItem,
            wallet: wallet,
            ledgerDevice: ledgerDevice,
            bleTransport: coreAssembly.ledgerAssembly.bleTransport,
            knownJettonResolver: knownJettonResolver
        )
        let viewController = LedgerConfirmViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}

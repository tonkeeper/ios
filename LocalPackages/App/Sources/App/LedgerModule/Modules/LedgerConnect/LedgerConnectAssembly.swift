import Foundation
import KeeperCore
import TKCore

struct LedgerConnectAssembly {
    private init() {}
    /// Without `readsAccounts` Continue hands over the connected Ledger alone, without waiting for the TON app.
    static func module(
        coreAssembly: TKCore.CoreAssembly,
        readsAccounts: Bool = true
    ) -> MVVMModule<LedgerConnectViewController, LedgerConnectModuleOutput, Void> {
        let viewModel = LedgerConnectViewModelImplementation(
            urlOpener: coreAssembly.urlOpener(),
            transport: coreAssembly.ledgerAssembly.transport,
            readsAccounts: readsAccounts
        )
        let viewController = LedgerConnectViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}

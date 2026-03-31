import Foundation
import KeeperCore
import TKCore

struct LedgerConnectAssembly {
    private init() {}
    static func module(coreAssembly: TKCore.CoreAssembly) -> MVVMModule<LedgerConnectViewController, LedgerConnectModuleOutput, Void> {
        let viewModel = LedgerConnectViewModelImplementation(
            urlOpener: coreAssembly.urlOpener(),
            bleTransport: coreAssembly.ledgerAssembly.bleTransport
        )
        let viewController = LedgerConnectViewController(viewModel: viewModel)
        return .init(view: viewController, output: viewModel, input: ())
    }
}

import Foundation
import KeeperCore
import TKCore

@MainActor
struct TransactionConfirmationAssembly {
    private init() {}
    static func module(
        transactionConfirmationController: TransactionConfirmationController,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<TransactionConfirmationViewController, TransactionConfirmationOutput, Void> {
        let viewModel = TransactionConfirmationViewModelImplementation(
            confirmationController: transactionConfirmationController,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            fundsValidator: keeperCoreMainAssembly.loadersAssembly.insufficientFundsValidator(),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            ratesService: keeperCoreMainAssembly.servicesAssembly.ratesService(),
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )
        let viewController = TransactionConfirmationViewController(viewModel: viewModel)

        return .init(view: viewController, output: viewModel, input: ())
    }
}

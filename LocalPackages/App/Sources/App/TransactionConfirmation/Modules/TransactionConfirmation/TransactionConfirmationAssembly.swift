import Foundation
import KeeperCore
import TKCore
import TKFeatureFlags

@MainActor
struct TransactionConfirmationAssembly {
    private init() {}
    static func module(
        transactionConfirmationController: TransactionConfirmationController,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        featureFlags: TKFeatureFlags,
        withdrawDisplayInfo: WithdrawDisplayInfo? = nil
    ) -> MVVMModule<TransactionConfirmationViewController, TransactionConfirmationOutput, Void> {
        let viewModel = TransactionConfirmationViewModelImplementation(
            confirmationController: transactionConfirmationController,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            fundsValidator: keeperCoreMainAssembly.loadersAssembly.insufficientFundsValidator(),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            ratesService: keeperCoreMainAssembly.servicesAssembly.ratesService(),
            balanceService: keeperCoreMainAssembly.servicesAssembly.balanceService(),
            batteryCalculation: keeperCoreMainAssembly.batteryAssembly.batteryCalculation,
            configurationAssembly: keeperCoreMainAssembly.configurationAssembly,
            withdrawDisplayInfo: withdrawDisplayInfo
        )
        let viewController = TransactionConfirmationViewController(viewModel: viewModel)

        return .init(view: viewController, output: viewModel, input: ())
    }
}

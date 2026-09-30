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
        transactionSentNotificationPatch: @escaping (inout [String: Any]) -> Void = { _ in },
        withdrawDisplayInfo: WithdrawDisplayInfo? = nil
    ) -> MVVMModule<TransactionConfirmationViewController, TransactionConfirmationOutput, Void> {
        let viewModel = TransactionConfirmationViewModelImplementation(
            confirmationController: transactionConfirmationController,
            pendingTransactionsService: keeperCoreMainAssembly.servicesAssembly.pendingTransactionsService(),
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            fundsValidator: keeperCoreMainAssembly.loadersAssembly.insufficientFundsValidator(),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            ratesService: keeperCoreMainAssembly.servicesAssembly.ratesService(),
            balanceService: keeperCoreMainAssembly.servicesAssembly.balanceService(),
            multichainAssetBalanceProvider: keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider,
            batteryCalculation: keeperCoreMainAssembly.batteryAssembly.batteryCalculation,
            configurationAssembly: keeperCoreMainAssembly.configurationAssembly,
            transactionSentNotificationPatch: transactionSentNotificationPatch,
            withdrawDisplayInfo: withdrawDisplayInfo
        )
        let viewController = TransactionConfirmationViewController(viewModel: viewModel)

        return .init(view: viewController, output: viewModel, input: ())
    }
}

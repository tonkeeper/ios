import Foundation
import KeeperCore
import TKCore
import UIKit

typealias NativeSwapTransactionConfirmation = MVVMModule<UIViewController, NativeSwapTransactionConfirmationModuleOutput, Void>

@MainActor
enum NativeSwapTransactionConfirmationAssembly {
    static func module(
        wallet: Wallet,
        model: NativeSwapTransactionConfirmationModel,
        transactionConfirmationController: TransactionConfirmationController,
        keeperCoreAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) -> NativeSwapTransactionConfirmation {
        let viewModel = NativeSwapTransactionConfirmationViewModelImplementation(
            wallet: wallet,
            sendController: keeperCoreAssembly.sendV3Controller(wallet: wallet),
            confirmationController: transactionConfirmationController,
            pendingTransactionsService: keeperCoreAssembly.servicesAssembly.pendingTransactionsService(),
            model: model,
            amountFormatter: keeperCoreAssembly.formattersAssembly.amountFormatter,
            fundsValidator: keeperCoreAssembly.loadersAssembly.insufficientFundsValidator(),
            currencyStore: keeperCoreAssembly.storesAssembly.currencyStore,
            nativeSwapService: keeperCoreAssembly.servicesAssembly.nativeSwapService(),
            batteryCalculation: keeperCoreAssembly.batteryAssembly.batteryCalculation,
            configurationAssembly: keeperCoreAssembly.configurationAssembly,
            configuration: keeperCoreAssembly.configurationAssembly.configuration,
            analyticsProvider: coreAssembly.analyticsProvider
        )

        let viewController = NativeSwapTransactionConfirmationViewController(
            viewModel: viewModel
        )

        return NativeSwapTransactionConfirmation(
            view: viewController,
            output: viewModel,
            input: ()
        )
    }
}

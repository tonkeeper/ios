import Foundation
import KeeperCore
import TKCore
import UIKit

struct InsertAmountAssembly {
    private init() {}

    @MainActor
    static func module(
        flow: RampFlow,
        asset: RampAsset,
        paymentMethod: OnRampLayoutCashMethod,
        currency: RemoteCurrency,
        wallet: Wallet,
        onRampLayout: OnRampLayout,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        analyticsProvider: AnalyticsProvider
    ) -> MVVMModule<InsertAmountViewController, InsertAmountModuleOutput, InsertAmountModuleInput> {
        let (sourceUnit, destinationUnit): (any AmountInputUnit, any AmountInputUnit)
        switch flow {
        case .deposit:
            (sourceUnit, destinationUnit) = (currency, asset)
        case .withdraw:
            (sourceUnit, destinationUnit) = (asset, currency)
        }
        let amountInput = AmountInputAssembly.module(
            sourceUnit: sourceUnit,
            destinationUnit: destinationUnit,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        let viewModel = InsertAmountViewModel(
            flow: flow,
            asset: asset,
            paymentMethod: paymentMethod,
            currency: currency,
            wallet: wallet,
            processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            onRampService: keeperCoreMainAssembly.servicesAssembly.onRampService(),
            amountInputModuleInput: amountInput.input,
            amountInputModuleOutput: amountInput.output,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            analyticsProvider: analyticsProvider
        )

        let viewController = InsertAmountViewController(
            viewModel: viewModel,
            amountInputViewController: amountInput.view
        )

        return MVVMModule(view: viewController, output: viewModel, input: viewModel)
    }
}

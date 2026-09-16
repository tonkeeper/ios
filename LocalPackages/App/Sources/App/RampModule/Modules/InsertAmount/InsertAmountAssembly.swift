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
        onRampLayout _: OnRampLayout,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        analyticsProvider: AnalyticsProvider
    ) -> MVVMModule<InsertAmountViewController, InsertAmountModuleOutput, InsertAmountModuleInput> {
        let quoteService = LegacyInsertAmountQuoteService(
            wallet: wallet,
            asset: asset,
            onRampService: keeperCoreMainAssembly.servicesAssembly.onRampService()
        )

        return makeModule(
            flow: flow,
            assetContext: .legacy(asset),
            paymentMethodContext: InsertAmountPaymentMethodContext(paymentMethod),
            currency: currency,
            wallet: wallet,
            quoteService: quoteService,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            analyticsProvider: analyticsProvider
        )
    }

    @MainActor
    static func multichainModule(
        flow: RampFlow,
        asset: MultichainAsset,
        paymentMethod: OnRampPaymentMethod,
        assetDetail: OnRampAssetDetail,
        currency: RemoteCurrency,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        multichainRampService: MultichainRampService,
        analyticsProvider: AnalyticsProvider
    ) -> MVVMModule<InsertAmountViewController, InsertAmountModuleOutput, InsertAmountModuleInput> {
        let quoteService = MultichainInsertAmountQuoteService(
            wallet: wallet,
            assetDetail: assetDetail,
            multichainRampService: multichainRampService,
            onRampService: keeperCoreMainAssembly.servicesAssembly.onRampService()
        )

        return makeModule(
            flow: flow,
            assetContext: .multichain(asset),
            paymentMethodContext: InsertAmountPaymentMethodContext(paymentMethod, currencyCode: currency.code),
            currency: currency,
            wallet: wallet,
            quoteService: quoteService,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            analyticsProvider: analyticsProvider
        )
    }

    @MainActor
    private static func makeModule(
        flow: RampFlow,
        assetContext: InsertAmountAssetContext,
        paymentMethodContext: InsertAmountPaymentMethodContext,
        currency: RemoteCurrency,
        wallet: Wallet,
        quoteService: InsertAmountQuoteServicing,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        analyticsProvider: AnalyticsProvider
    ) -> MVVMModule<InsertAmountViewController, InsertAmountModuleOutput, InsertAmountModuleInput> {
        let (sourceUnit, destinationUnit): (any AmountInputUnit, any AmountInputUnit)
        switch flow {
        case .deposit:
            (sourceUnit, destinationUnit) = (currency, assetContext.amountInputUnit)
        case .withdraw:
            (sourceUnit, destinationUnit) = (assetContext.amountInputUnit, currency)
        }
        let amountInput = AmountInputAssembly.module(
            sourceUnit: sourceUnit,
            destinationUnit: destinationUnit,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        let viewModel = InsertAmountViewModel(
            flow: flow,
            assetContext: assetContext,
            paymentMethodContext: paymentMethodContext,
            currency: currency,
            wallet: wallet,
            processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            quoteService: quoteService,
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

private extension InsertAmountAssetContext {
    var amountInputUnit: any AmountInputUnit {
        switch self {
        case let .legacy(asset):
            return asset
        case let .multichain(asset):
            return asset
        }
    }
}

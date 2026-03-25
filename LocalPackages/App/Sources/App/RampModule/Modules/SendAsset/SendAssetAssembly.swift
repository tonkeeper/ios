import Foundation
import KeeperCore
import TKCore
import UIKit

struct SendAssetAssembly {
    private init() {}

    static func module(
        fromAsset: OnRampLayoutCryptoMethod,
        toAsset: OnRampLayoutToken,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        analyticsProvider: AnalyticsProvider
    ) -> MVVMModule<SendAssetViewController, SendAssetViewModel, Void> {
        let onRampService = keeperCoreMainAssembly.servicesAssembly.onRampService()
        let amountFormatter = keeperCoreMainAssembly.formattersAssembly.amountFormatter
        let viewModel = SendAssetViewModel(
            fromAsset: fromAsset,
            toAsset: toAsset,
            wallet: wallet,
            onRampService: onRampService,
            amountFormatter: amountFormatter,
            analyticsProvider: analyticsProvider
        )
        let viewController = SendAssetViewController(viewModel: viewModel)
        return MVVMModule(view: viewController, output: viewModel, input: ())
    }
}

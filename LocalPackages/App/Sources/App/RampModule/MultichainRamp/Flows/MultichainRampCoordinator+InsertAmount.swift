import Foundation
import KeeperCore
import TKCore
import TKLogging
import TKUIKit
import UIKit

extension MultichainRampCoordinator {
    func openInsertAmount(
        asset: MultichainAsset,
        paymentMethod: OnRampPaymentMethod,
        assetDetail: OnRampAssetDetail,
        currency: RemoteCurrency
    ) {
        let module = InsertAmountAssembly.multichainModule(
            flow: flow,
            asset: asset,
            paymentMethod: paymentMethod,
            assetDetail: assetDetail,
            currency: currency,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            multichainRampService: multichainRampService,
            analyticsProvider: coreAssembly.analyticsProvider
        )

        module.output.didTapBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }

        module.output.didTapClose = { [weak self] in
            self?.finishFlow()
        }

        module.output.didTapProvider = { [weak self] items, selectedMerchant in
            guard let self else { return }
            openProviderPicker(
                items: items,
                selectedMerchant: selectedMerchant,
                insertAmountModuleInput: module.input,
                fromViewController: module.view
            )
        }

        module.output.didTapContinue = { [weak self] context, merchantInfo, widgetURL in
            guard let self else { return }
            guard let widgetURL else {
                Log.multichainRamp.w(
                    "continue blocked - merchant returned no widget url",
                    extraInfo: [
                        "flow": flow.api,
                        "assetId": asset.asset.assetId,
                        "merchantId": merchantInfo.id,
                        "currency": currency.code,
                    ]
                )
                return
            }

            logDepositContinueToRampProvider(
                assetId: asset.asset.assetId,
                paymentMethod: paymentMethod.type,
                currencyCode: currency.code,
                context: context
            )
            didTapOpenMerchant?(widgetURL)
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openProviderPicker(
        items: [ProviderPickerItem],
        selectedMerchant: OnRampMerchantInfo,
        insertAmountModuleInput: InsertAmountModuleInput,
        fromViewController: UIViewController
    ) {
        let providerPickerModule = ProviderPickerAssembly.module(items: items)

        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: providerPickerModule.view
        )

        providerPickerModule.output.didTapClose = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }
        providerPickerModule.output.didSelectMerchant = { [weak bottomSheetViewController] merchant in
            insertAmountModuleInput.setSelectedMerchant(merchant)
            bottomSheetViewController?.dismiss()
        }

        bottomSheetViewController.present(fromViewController: fromViewController)
    }
}

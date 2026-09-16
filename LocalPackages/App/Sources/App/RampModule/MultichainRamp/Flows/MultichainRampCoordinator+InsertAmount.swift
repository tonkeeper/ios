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

        module.output.didLoadInitialMerchant = { merchant in
            guard let merchant else { return }
            // Deposit analytics for multichain assets are not mapped yet.
            _ = merchant
        }

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

        module.output.didTapContinue = { [weak self] _, merchantInfo, widgetURL in
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

            let shouldSkipWarning = coreAssembly.appSettings.isBuySellItemMarkedDoNotShowWarning(merchantInfo.id)

            if shouldSkipWarning {
                didTapOpenMerchant?(widgetURL)
                return
            }

            openOnRampMerchantWarning(
                merchantInfo: merchantInfo,
                widgetURL: widgetURL,
                fromViewController: module.view
            )
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

    func openOnRampMerchantWarning(
        merchantInfo: OnRampMerchantInfo,
        widgetURL: URL,
        fromViewController: UIViewController
    ) {
        let popupModule = RampMerchantPopUpAssembly.module(
            merchantInfo: merchantInfo,
            actionURL: widgetURL,
            appSettings: coreAssembly.appSettings,
            urlOpener: coreAssembly.urlOpener()
        )

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: popupModule.view)
        bottomSheetViewController.present(fromViewController: fromViewController)

        popupModule.output.didTapOpen = { [weak bottomSheetViewController, weak self] url in
            bottomSheetViewController?.dismiss {
                self?.didTapOpenMerchant?(url)
            }
        }
    }
}

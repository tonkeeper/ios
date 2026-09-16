import Foundation
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import UIKit

final class MultichainRampCoordinator: RouterCoordinator<NavigationControllerRouter> {
    enum Mode {
        case withdraw(MultichainAsset?)
        case deposit(MultichainAsset?)

        var flow: RampFlow {
            switch self {
            case .withdraw:
                .withdraw
            case .deposit:
                .deposit
            }
        }

        var initialAsset: MultichainAsset? {
            switch self {
            case let .withdraw(asset), let .deposit(asset):
                asset
            }
        }
    }

    var didClose: (() -> Void)?
    var didTapReceiveTokens: ((Wallet) -> Void)?
    var didTapBuyWithP2P: ((Wallet) -> Void)?
    var didTapOpenMerchant: ((URL) -> Void)?

    let mode: Mode

    var flow: RampFlow {
        mode.flow
    }

    let wallet: Wallet
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    let coreAssembly: TKCore.CoreAssembly
    let multichainRampService: MultichainRampService
    init(
        mode: Mode,
        router: NavigationControllerRouter,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        multichainRampService: MultichainRampService
    ) {
        self.mode = mode
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.multichainRampService = multichainRampService
        super.init(router: router)
    }

    override func start() {
        Log.multichainRamp.i(
            "flow started",
            extraInfo: [
                "flow": flow.api,
                "assetId": mode.initialAsset?.asset.assetId ?? "",
            ]
        )
        if let initialAsset = mode.initialAsset {
            openPaymentMethod(asset: initialAsset, isRoot: true)
            return
        }
        openRampOn()
    }

    var navigationController: UINavigationController {
        router.rootViewController
    }
}

extension MultichainRampCoordinator {
    func finishFlow() {
        keeperCoreMainAssembly.servicesAssembly.onRampService().clearCachedOnRampResponses()
        keeperCoreMainAssembly.servicesAssembly.currenciesService().clearCachedCurrencies()
        didClose?()
    }

    func openRampOn() {
        let viewModel = RampOnViewModel(
            flow: flow,
            multichainRampService: multichainRampService,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore
        )

        viewModel.onClose = { [weak self] in
            self?.finishFlow()
        }

        viewModel.onTapReceiveTokens = { [weak self] in
            guard let self else { return }
            self.didTapReceiveTokens?(self.wallet)
        }

        viewModel.onTapLayoutCard = { [weak self] card in
            self?.openAssetPicker(preferredFiat: card.preferredCurrency)
        }

        let viewController = RampOnViewController(viewModel: viewModel)
        navigationController.setViewControllers([viewController], animated: false)
    }

    func openAssetPicker(preferredFiat: String?) {
        guard flow == .deposit else {
            Log.multichainRamp.w("asset picker skipped - unsupported flow", extraInfo: ["flow": flow.api])
            return
        }

        let model = RampAssetPickerModel(
            multichainRampService: multichainRampService,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            preferredFiat: preferredFiat,
            walletId: wallet.multichainWalletId
        )
        let module = TokenPickerV2Assembly.module(
            title: TKLocales.Ramp.Picker.chooseAssetTitle,
            wallet: wallet,
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            presentation: .pushed,
            onBack: { [weak self] in
                self?.navigationController.popViewController(animated: true)
            }
        )

        module.output.didSelectAsset = { [weak self] asset in
            self?.openPaymentMethod(asset: asset, preferredFiat: preferredFiat)
        }

        module.output.didFinish = { [weak self] in
            self?.finishFlow()
        }

        navigationController.pushViewController(module.view, animated: true)
    }

    func openPaymentMethod(
        asset: MultichainAsset,
        preferredFiat: String? = nil,
        isRoot: Bool = false
    ) {
        let viewModel = RampPaymentMethodViewModel(
            asset: asset,
            flow: flow,
            preferredFiat: preferredFiat,
            multichainRampService: multichainRampService,
            currenciesService: keeperCoreMainAssembly.servicesAssembly.currenciesService(),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            walletId: wallet.multichainWalletId
        )

        viewModel.onClose = { [weak self] in
            self?.finishFlow()
        }

        viewModel.onBack = { [weak self] in
            if isRoot {
                self?.finishFlow()
            } else {
                self?.navigationController.popViewController(animated: true)
            }
        }

        viewModel.onSelectCurrency = { [weak self, weak viewModel] currencies, selected in
            self?.openCurrencyPicker(
                currencies: currencies,
                selected: selected,
                onCurrencySelected: { [weak viewModel] currency in
                    viewModel?.setCurrency(currency)
                }
            )
        }

        viewModel.onSelectPaymentMethod = { [weak self] row, currency, assetDetail in
            guard let self else { return }
            if row.isP2P {
                openP2PExpress(asset: asset, currencyCode: currency.code)
                return
            }
            guard let paymentMethod = assetDetail.paymentMethods.first(where: { $0.type == row.type }) else {
                Log.multichainRamp.w(
                    "payment method not found in asset detail",
                    extraInfo: [
                        "flow": flow.api,
                        "assetId": asset.asset.assetId,
                        "row": row.type,
                        "available": assetDetail.paymentMethods.map(\.type).pretty.string,
                    ]
                )
                return
            }
            openInsertAmount(
                asset: asset,
                paymentMethod: paymentMethod,
                assetDetail: assetDetail,
                currency: currency
            )
        }

        let viewController = RampPaymentMethodViewController(viewModel: viewModel)
        if isRoot {
            navigationController.setViewControllers([viewController], animated: false)
        } else {
            navigationController.pushViewController(viewController, animated: true)
        }
    }

    func openCurrencyPicker(
        currencies: [RemoteCurrency],
        selected: RemoteCurrency,
        onCurrencySelected: @escaping (RemoteCurrency) -> Void
    ) {
        let model = RampPickerCurrencyModel(currencies: currencies, selected: selected)

        let pickerModule = RampPickerAssembly.module(model: model, flow: flow)
        pickerModule.output.didSelectCurrency = { [weak self] currency in
            onCurrencySelected(currency)
            self?.navigationController.popViewController(animated: true)
        }
        pickerModule.output.didTapBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        pickerModule.output.didTapClose = { [weak self] in
            self?.finishFlow()
        }
        pickerModule.view.setupBackButton()

        navigationController.pushViewController(pickerModule.view, animated: true)
    }
}

import BigInt
import Foundation
import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

public final class RampCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didClose: (() -> Void)?

    private let flow: RampFlow
    private let tokens: [Token]
    private let initialWallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    var didTapReceive: (([Token], Wallet) -> Void)?
    var didTapSend: ((Wallet, TonToken) -> Void)?
    var didTapOpenSendFromWithdraw: ((Wallet, SendInput) -> Void)?
    var didTapOpenMerchant: ((URL) -> Void)?
    var didRequestTRC20Enable: ((Wallet, @escaping () -> Void) -> Void)?

    var wallet: Wallet {
        keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: initialWallet.id) ?? initialWallet
    }

    init(
        flow: RampFlow,
        router: NavigationControllerRouter,
        tokens: [Token],
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.flow = flow
        self.tokens = tokens
        self.initialWallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly

        super.init(router: router)
    }

    override public func start() {
        openRamp()
    }
}

private extension RampCoordinator {
    func finishRampFlow() {
        keeperCoreMainAssembly.servicesAssembly.onRampService().clearCachedOnRampResponses()
        keeperCoreMainAssembly.servicesAssembly.currenciesService().clearCachedCurrencies()
        didClose?()
    }

    var navigationController: UINavigationController {
        router.rootViewController
    }

    var depositSource: DepositAnalyticsSource {
        .walletScreen
    }

    var withdrawSource: WithdrawAnalyticsSource {
        .walletScreen
    }

    func openRamp() {
        let module = RampAssembly.module(
            flow: flow,
            wallet: wallet,
            keeperCoreAssembly: keeperCoreMainAssembly
        )

        logOpenIfNeeded()

        module.output.didTapReceiveTokens = { [weak self] in
            guard let self else { return }
            self.logDepositReceiveIfNeeded()
            self.didTapReceive?(self.tokens, self.wallet)
        }

        module.output.didTapSendTokens = { [weak self] in
            guard let self else { return }
            self.logWithdrawClickSendTokensIfNeeded()
            self.didTapSend?(self.wallet, .ton)
        }

        module.output.didTapItem = { [weak self] asset, onRampLayout in
            guard let self else { return }
            guard !asset.isTronNetwork || wallet.isTronAvailable else {
                return
            }
            self.logAssetClickIfNeeded(asset: asset)
            if asset.isTronNetwork, !wallet.isTronTurnOn {
                self.didRequestTRC20Enable?(wallet) { [weak self] in
                    self?.openPaymentMethod(asset: asset, onRampLayout: onRampLayout)
                }
            } else {
                self.openPaymentMethod(asset: asset, onRampLayout: onRampLayout)
            }
        }

        module.output.didClose = { [weak self] in
            self?.finishRampFlow()
        }

        navigationController.setViewControllers([module.view], animated: false)
    }

    func openPaymentMethod(asset: RampAsset, onRampLayout: OnRampLayout) {
        let paymentMethodModule = PaymentMethodAssembly.module(
            flow: flow,
            asset: asset,
            onRampLayout: onRampLayout,
            isTRC20Available: wallet.isTronAvailable,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        paymentMethodModule.output.didTapBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        paymentMethodModule.output.didTapClose = { [weak self] in
            self?.finishRampFlow()
        }
        paymentMethodModule.output.didSelectCurrency = { [weak self] currencies, selected in
            self?.openCurrencyPicker(
                currencies: currencies,
                selected: selected,
                paymentMethodInput: paymentMethodModule.input
            )
        }
        paymentMethodModule.output.didSelectCashMethod = { [weak self] method, onRampLayout, currency in
            if method.isP2P {
                self?.openP2PExpress(asset: asset, currency: currency)
            } else {
                self?.openInsertAmount(asset: asset, paymentMethod: method, currency: currency, onRampLayout: onRampLayout)
            }
        }

        paymentMethodModule.output.didTapAllMethods = { [weak self] methods, onRampLayout, currency in
            self?.openPaymentMethodPicker(methods: methods) { [weak self] method in
                if method.isP2P {
                    self?.openP2PExpress(asset: asset, currency: currency)
                } else {
                    self?.openInsertAmount(asset: asset, paymentMethod: method, currency: currency, onRampLayout: onRampLayout)
                }
            }
        }
        paymentMethodModule.output.didSelectCryptoAsset = { [weak self] selectedAsset in
            self?.openSendAsset(fromAsset: selectedAsset, toAsset: asset)
        }
        paymentMethodModule.output.didTapAllAssets = { [weak self] assets in
            self?.openCryptoPicker(
                assets: assets,
                onSelectCrypto: { [weak self] selectedAsset in
                    self?.openSendAsset(fromAsset: selectedAsset, toAsset: asset)
                }
            )
        }
        paymentMethodModule.output.didSelectStablecoin = { [weak self] networks in
            if networks.count == 1, let selectedAsset = networks.first {
                guard let self else { return }
                switch self.flow {
                case .deposit:
                    self.openSendAsset(fromAsset: selectedAsset, toAsset: asset)
                case .withdraw:
                    self.didTapOpenSendFromWithdraw?(self.wallet, .withdraw(sourceAsset: asset, exchangeTo: selectedAsset))
                }
            } else {
                self?.openNetworkPicker(networks: networks) { [weak self] selectedAsset in
                    guard let self else { return }
                    switch self.flow {
                    case .deposit:
                        self.openSendAsset(fromAsset: selectedAsset, toAsset: asset)
                    case .withdraw:
                        self.didTapOpenSendFromWithdraw?(self.wallet, .withdraw(sourceAsset: asset, exchangeTo: selectedAsset))
                    }
                }
            }
        }

        navigationController.pushViewController(paymentMethodModule.view, animated: true)
    }

    func openPaymentMethodPicker(
        methods: [OnRampLayoutCashMethod],
        onSelect: @escaping (OnRampLayoutCashMethod) -> Void
    ) {
        guard !methods.isEmpty else { return }
        let model = RampPickerPaymentMethodModel(methods: methods)
        let pickerModule = RampPickerAssembly.module(model: model, flow: flow)

        pickerModule.output.didSelectPaymentMethod = onSelect
        pickerModule.output.didTapBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        pickerModule.output.didTapClose = { [weak self] in
            self?.finishRampFlow()
        }
        pickerModule.view.setupBackButton()

        navigationController.pushViewController(pickerModule.view, animated: true)
    }

    func openNetworkPicker(
        networks: [OnRampLayoutCryptoMethod],
        onSelect: @escaping (OnRampLayoutCryptoMethod) -> Void
    ) {
        guard let first = networks.first else { return }
        let stablecoinCode = first.symbol
        let model = RampPickerNetworkModel(assets: networks, stablecoinCode: stablecoinCode)
        let pickerModule = RampPickerAssembly.module(model: model, flow: flow)
        pickerModule.output.didSelectNetworkAsset = onSelect
        pickerModule.output.didTapBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        pickerModule.output.didTapClose = { [weak self] in
            self?.finishRampFlow()
        }
        pickerModule.view.setupBackButton()

        navigationController.pushViewController(pickerModule.view, animated: true)
    }

    func openSendAsset(fromAsset: OnRampLayoutCryptoMethod, toAsset: OnRampLayoutToken) {
        let module = SendAssetAssembly.module(
            fromAsset: fromAsset,
            toAsset: toAsset,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            analyticsProvider: coreAssembly.analyticsProvider
        )
        module.output.didTapBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        module.output.didTapClose = { [weak self] in
            self?.finishRampFlow()
        }
        module.output.didTapGoToMain = { [weak self] in
            self?.finishRampFlow()
        }
        module.output.didTapQRCode = { [weak self] data in
            self?.openPaymentQRCode(data: data)
        }
        navigationController.pushViewController(module.view, animated: true)
    }

    func openPaymentQRCode(data: PaymentQRCodeData) {
        let module = PaymentQRCodeAssembly.module(data: data)
        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: module.view
        )
        module.output.didTapClose = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }
        bottomSheetViewController.present(fromViewController: navigationController)
    }

    func openCurrencyPicker(currencies: [RemoteCurrency], selected: RemoteCurrency, paymentMethodInput: PaymentMethodModuleInput) {
        let model = RampPickerCurrencyModel(currencies: currencies, selected: selected)

        let pickerModule = RampPickerAssembly.module(model: model, flow: flow)
        pickerModule.output.didSelectCurrency = { [weak self, weak paymentMethodInput] currency in
            paymentMethodInput?.set(currency: currency)
            self?.navigationController.popViewController(animated: true)
        }
        pickerModule.output.didTapBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        pickerModule.output.didTapClose = { [weak self] in
            self?.finishRampFlow()
        }
        pickerModule.view.setupBackButton()

        navigationController.pushViewController(pickerModule.view, animated: true)
    }

    func openP2PExpress(asset: RampAsset, currency: RemoteCurrency) {
        logViewP2PIfNeeded(asset: asset)

        let walletAddress: String
        if asset.isTronNetwork, let address = wallet.tron?.address.base58 {
            walletAddress = address
        } else if let address = try? self.wallet.friendlyAddress.toString() {
            walletAddress = address
        } else {
            return
        }

        let params = P2PExpressParams(
            wallet: walletAddress,
            network: asset.network.lowercased(),
            cryptoCurrency: asset.symbol,
            fiatCurrency: currency.code,
            amount: nil,
            requestNetwork: wallet.network
        )

        let p2pModule = P2PExpressModule(
            dependencies: P2PExpressModule.Dependencies(
                onRampService: keeperCoreMainAssembly.servicesAssembly.onRampService()
            )
        )

        let coordinator = p2pModule.createP2PExpressCoordinator(
            router: ViewControllerRouter(rootViewController: navigationController),
            params: params
        )

        coordinator.didTapOpen = { url, _ in
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        coordinator.didFailToCreateSession = { error in
            // [DEPSIT] TODO: - fix
            ToastPresenter.showToast(configuration: .init(title: error.localizedDescription))
        }
        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openInsertAmount(asset: RampAsset, paymentMethod: OnRampLayoutCashMethod, currency: RemoteCurrency, onRampLayout: OnRampLayout) {
        let module = InsertAmountAssembly.module(
            flow: flow,
            asset: asset,
            paymentMethod: paymentMethod,
            currency: currency,
            wallet: wallet,
            onRampLayout: onRampLayout,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            analyticsProvider: coreAssembly.analyticsProvider
        )
        module.output.didTapBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        module.output.didTapClose = { [weak self] in
            self?.finishRampFlow()
        }
        module.output.didTapProvider = { [weak self] items, selectedMerchant in
            guard let self else { return }
            self.openProviderPicker(
                items: items,
                selectedMerchant: selectedMerchant,
                insertAmountModuleInput: module.input,
                fromViewController: module.view
            )
        }
        module.output.didTapContinue = { [weak self] context, merchantInfo, widgetURL in
            guard let self, let widgetURL else { return }

            let shouldSkipWarning = self.coreAssembly.appSettings.isBuySellItemMarkedDoNotShowWarning(merchantInfo.id)

            if shouldSkipWarning {
                self.openOnRampProviderFlow(url: widgetURL, asset: asset, context: context)
                return
            }

            self.openOnRampMerchantWarning(
                merchantInfo: merchantInfo,
                asset: asset,
                context: context,
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
        asset: RampAsset,
        context: RampOnrampContinueContext,
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
                self?.openOnRampProviderFlow(url: url, asset: asset, context: context)
            }
        }
    }

    func openOnRampProviderFlow(url: URL, asset: RampAsset, context: RampOnrampContinueContext) {
        logViewOnrampFlowIfNeeded(asset: asset, context: context)
        didTapOpenMerchant?(url)
    }

    func openCryptoPicker(
        assets: [OnRampLayoutCryptoMethod],
        onSelectCrypto: @escaping (OnRampLayoutCryptoMethod) -> Void
    ) {
        let cryptoItems: [CryptoPickerItem] = assets.map { method in
            let image: TKImage? = URL(string: method.image).map { .urlImage($0) }
            return CryptoPickerItem(
                identifier: method.cryptoPickerIdentifier,
                symbol: method.symbol,
                networkName: method.networkName,
                network: method.network,
                image: image
            )
        }

        let model = RampPickerCryptoModel(items: cryptoItems, selectedId: nil)
        let pickerModule = RampPickerAssembly.module(model: model, flow: flow)
        pickerModule.output.didSelectCryptoItem = { item in
            let method = assets.first { $0.cryptoPickerIdentifier == item.identifier }
            if let method {
                onSelectCrypto(method)
            }
        }
        pickerModule.output.didTapBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        pickerModule.output.didTapClose = { [weak self] in
            self?.finishRampFlow()
        }
        pickerModule.view.setupBackButton()

        navigationController.pushViewController(pickerModule.view, animated: true)
    }

    func logOpenIfNeeded() {
        switch flow {
        case .deposit:
            coreAssembly.analyticsProvider.log(
                DepositOpen(from: depositSource.depositOpen)
            )
        case .withdraw:
            coreAssembly.analyticsProvider.log(
                WithdrawOpen(from: withdrawSource.withdrawOpen)
            )
        }
    }

    func logAssetClickIfNeeded(asset: RampAsset) {
        switch flow {
        case .deposit:
            guard let buyAsset = asset.depositAnalyticsAssetIdentifier.flatMap(DepositClickBuy.BuyAsset.init(rawValue:)) else { return }
            coreAssembly.analyticsProvider.log(DepositClickBuy(buyAsset: buyAsset))
        case .withdraw:
            guard let sellAsset = asset.withdrawAnalyticsAssetIdentifier.flatMap(WithdrawClickSell.SellAsset.init(rawValue:)) else { return }
            coreAssembly.analyticsProvider.log(
                WithdrawClickSell(
                    from: withdrawSource.withdrawClickSell,
                    sellAsset: sellAsset
                )
            )
        }
    }

    func logDepositReceiveIfNeeded() {
        guard flow == .deposit else { return }
        coreAssembly.analyticsProvider.log(
            DepositClickReceiveTokens(from: depositSource.depositClickReceiveTokens)
        )
    }

    func logWithdrawClickSendTokensIfNeeded() {
        guard flow == .withdraw else { return }
        coreAssembly.analyticsProvider.log(
            WithdrawClickSendTokens(from: withdrawSource.withdrawClickSendTokens)
        )
    }

    func logViewP2PIfNeeded(asset: RampAsset) {
        switch flow {
        case .deposit:
            guard let buyAsset = asset.depositAnalyticsAssetIdentifier.flatMap(DepositViewP2p.BuyAsset.init(rawValue:)) else { return }
            coreAssembly.analyticsProvider.log(DepositViewP2p(buyAsset: buyAsset))
        case .withdraw:
            guard let sellAsset = asset.withdrawAnalyticsAssetIdentifier.flatMap(WithdrawViewP2p.SellAsset.init(rawValue:)) else { return }
            coreAssembly.analyticsProvider.log(
                WithdrawViewP2p(
                    sellAsset: sellAsset,
                    buyAsset: .fiat
                )
            )
        }
    }

    func logViewOnrampFlowIfNeeded(asset: RampAsset, context: RampOnrampContinueContext) {
        switch flow {
        case .deposit:
            guard let buyAsset = DepositViewOnrampFlow.BuyAsset(rawValue: asset.depositAnalyticsAssetIdentifier ?? "") else { return }
            coreAssembly.analyticsProvider.log(
                DepositViewOnrampFlow(
                    buyAsset: buyAsset,
                    providerName: context.providerName,
                    buyAmount: NSDecimalNumber(decimal: context.amount).floatValue,
                    txId: context.txId
                )
            )
        case .withdraw:
            guard let sellAsset = WithdrawViewOnrampFlow.SellAsset(rawValue: asset.withdrawAnalyticsAssetIdentifier ?? "") else { return }
            coreAssembly.analyticsProvider.log(
                WithdrawViewOnrampFlow(
                    sellAsset: sellAsset,
                    providerName: context.providerName,
                    sellAmount: NSDecimalNumber(decimal: context.amount).floatValue,
                    buyAsset: .fiat,
                    txId: context.txId
                )
            )
        }
    }
}

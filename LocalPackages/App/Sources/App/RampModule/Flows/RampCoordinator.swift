import BigInt
import Foundation
import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

final class RampCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didClose: (() -> Void)?

    private weak var rampModuleInput: RampModuleInput?

    let flow: RampFlow
    private let initialWallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    let coreAssembly: TKCore.CoreAssembly
    private let initialDeeplink: RampDeeplinkParameters?
    let entrySource: DepositAnalyticsSource
    var flowContext: DepositFlowContext
    let depositPendingTracker: DepositPendingTracker

    var didTapReceive: ((Wallet) -> Void)?
    var didTapSend: ((Wallet, TonToken) -> Void)?
    var didTapOpenSendFromWithdraw: ((Wallet, SendInput) -> Void)?
    var didTapOpenMerchant: ((URL) -> Void)?

    var wallet: Wallet {
        keeperCoreMainAssembly.storesAssembly.walletsStore.getWallet(id: initialWallet.id) ?? initialWallet
    }

    init(
        flow: RampFlow,
        router: NavigationControllerRouter,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        initialDeeplink: RampDeeplinkParameters?,
        entrySource: DepositAnalyticsSource,
        utm: UtmParameters = .empty,
        depositPendingTracker: DepositPendingTracker
    ) {
        self.flow = flow
        self.initialWallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        self.initialDeeplink = initialDeeplink
        self.entrySource = entrySource
        self.flowContext = DepositFlowContext(source: entrySource, utm: utm)
        self.depositPendingTracker = depositPendingTracker

        super.init(router: router)
    }

    override func start() {
        openRamp()
    }
}

private extension RampCoordinator {
    func finishRampFlow() {
        rampModuleInput = nil
        keeperCoreMainAssembly.servicesAssembly.onRampService().clearCachedOnRampResponses()
        keeperCoreMainAssembly.servicesAssembly.currenciesService().clearCachedCurrencies()
        didClose?()
    }

    var navigationController: UINavigationController {
        router.rootViewController
    }

    var depositSource: DepositAnalyticsSource {
        entrySource
    }

    var withdrawSource: WithdrawAnalyticsSource {
        .walletScreen
    }

    func openRamp() {
        let module = RampAssembly.module(
            flow: flow,
            wallet: wallet,
            keeperCoreAssembly: keeperCoreMainAssembly,
            initialDeeplink: initialDeeplink
        )

        logOpenIfNeeded()

        module.output.didOpenScreen = { [weak self] layout in
            self?.fireDepositStarted(availableOptions: layout.addFundsAvailableOptions)
        }

        module.output.didTapReceiveTokens = { [weak self] in
            guard let self else { return }
            self.logDepositReceiveIfNeeded()
            self.fireDepositOptionClick(option: .receiveTokens)
            self.didTapReceive?(self.wallet)
        }

        module.output.didTapSendTokens = { [weak self] in
            guard let self else { return }
            self.logWithdrawClickSendTokensIfNeeded()
            self.didTapSend?(self.wallet, .ton)
        }

        rampModuleInput = module.input

        module.output.didSelectFiatCurrency = { [weak self] currencies, selected in
            self?.openCurrencyPicker(
                currencies: currencies,
                selected: selected,
                onCurrencySelected: { [weak self] currency in
                    self?.rampModuleInput?.set(currency: currency)
                }
            )
        }

        module.output.didTapLayoutItem = { [weak self] item, _, deeplink, preselectedAsset in
            guard let self, let assets = item.assets, !assets.isEmpty else { return }
            if let filter = deeplink?.itemType, item.type != filter {
                return
            }
            if let option = item.type.depositAddFundsOption {
                self.fireDepositOptionClick(option: option)
            }
            if let preselected = preselectedAsset, assets.contains(preselected) {
                self.openPaymentMethodFromAssetSelection(asset: preselected, rampLayoutItem: item, initialDeeplink: deeplink)
                return
            }
            if assets.count == 1, let asset = assets.first {
                self.openPaymentMethodFromAssetSelection(asset: asset, rampLayoutItem: item, initialDeeplink: deeplink)
            } else {
                openAssetPicker(assets: assets, rampLayoutItem: item, onSelect: { [weak self] asset in
                    guard let self else { return }
                    self.openPaymentMethodFromAssetSelection(asset: asset, rampLayoutItem: item, initialDeeplink: deeplink)
                })
            }
        }

        module.output.didClose = { [weak self] in
            self?.finishRampFlow()
        }

        navigationController.setViewControllers([module.view], animated: false)
    }

    func openPaymentMethodFromAssetSelection(
        asset: RampAsset,
        rampLayoutItem: OnRampLayoutItem,
        initialDeeplink: RampDeeplinkParameters?
    ) {
        logAssetClickIfNeeded(asset: asset)
        fireAssetPickerSelectionEvent(asset: asset, rampLayoutItem: rampLayoutItem)
        openPaymentMethod(asset: asset, rampLayoutItem: rampLayoutItem, initialDeeplink: initialDeeplink)
    }

    func openPaymentMethod(asset: RampAsset, rampLayoutItem: OnRampLayoutItem, initialDeeplink: RampDeeplinkParameters?) {
        let paymentMethodModule = PaymentMethodAssembly.module(
            flow: flow,
            asset: asset,
            rampLayoutItem: rampLayoutItem,
            isTRC20Available: wallet.tron != nil,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            initialDeeplink: initialDeeplink,
            fiatCurrency: rampModuleInput?.currentFiatCurrency,
            walletId: wallet.multichainWalletId
        )

        firePaymentMethodScreenViewEvent(asset: asset, rampLayoutItem: rampLayoutItem)

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
                onCurrencySelected: { [weak paymentMethodInput = paymentMethodModule.input] currency in
                    paymentMethodInput?.set(currency: currency)
                }
            )
        }
        paymentMethodModule.output.didSelectCashMethod = { [weak self] method, onRampLayout, currency in
            guard let self else { return }
            self.flowContext.sellAsset = currency.code
            self.fireDepositClickFiatPaymentMethod(paymentMethod: method.type)
            if method.isP2P {
                self.openP2PExpress(asset: asset, currencyCode: currency.code)
            } else {
                self.openInsertAmount(asset: asset, paymentMethod: method, currency: currency, onRampLayout: onRampLayout)
            }
        }

        paymentMethodModule.output.didSelectCryptoMethod = { [weak self] cryptoMethod in
            self?.openSendAsset(fromAsset: cryptoMethod, toAsset: asset)
        }
        paymentMethodModule.output.didTapAllCryptoMethods = { [weak self] assets in
            self?.openCryptoPicker(
                assets: assets,
                onSelectCrypto: { [weak self] selectedAsset in
                    self?.openSendAsset(fromAsset: selectedAsset, toAsset: asset)
                }
            )
        }
        paymentMethodModule.output.didSelectStablecoin = { [weak self] networks in
            guard let self, let firstNetwork = networks.first else { return }
            self.fireDepositClickStablecoinPaymentMethod(stablecoinSymbol: firstNetwork.symbol)
            if networks.count == 1 {
                let selectedAsset = firstNetwork
                self.flowContext.sellAsset = selectedAsset.assetId
                switch self.flow {
                case .deposit:
                    self.openSendAsset(fromAsset: selectedAsset, toAsset: asset)
                case .withdraw:
                    self.didTapOpenSendFromWithdraw?(self.wallet, .withdraw(sourceAsset: asset, exchangeTo: selectedAsset))
                }
            } else {
                self.openNetworkPicker(networks: networks) { [weak self] selectedAsset in
                    guard let self else { return }
                    self.fireDepositClickNetwork(sellAsset: selectedAsset.assetId)
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

    func firePaymentMethodScreenViewEvent(asset: RampAsset, rampLayoutItem: OnRampLayoutItem) {
        guard flow == .deposit else { return }
        switch rampLayoutItem.type {
        case .crypto:
            let options = Set(asset.cryptoMethods.map(\.assetId))
            fireDepositViewBuyTonWithCrypto(availableOptions: options)
        case .fiat:
            let options = Set(asset.cashMethods.map(\.type))
            let currency = keeperCoreMainAssembly.storesAssembly.currencyStore.getState()
            fireDepositViewFiatPaymentMethod(sellAsset: currency.code, availableOptions: options)
        case .stablecoin:
            let options = Set(asset.cryptoMethods.map(\.symbol))
            fireDepositViewStablecoinPaymentMethod(availableOptions: options)
        }
    }

    func openNetworkPicker(
        networks: [OnRampLayoutCryptoMethod],
        onSelect: @escaping (OnRampLayoutCryptoMethod) -> Void
    ) {
        guard let first = networks.first else { return }
        let stablecoinCode = first.symbol
        let model = RampPickerNetworkModel(assets: networks, stablecoinCode: stablecoinCode)
        let pickerModule = RampPickerAssembly.module(model: model, flow: flow)
        let networkOptions = Set(networks.map(\.network))
        fireDepositViewChooseNetwork(availableOptions: networkOptions)
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
            analyticsProvider: coreAssembly.analyticsProvider,
            flow: flow
        )
        fireDepositViewSendAsset(
            sellAsset: fromAsset.assetId,
            buyAsset: toAsset.assetId
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
        let module = PaymentQRCodeAssembly.module(
            data: data,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        fireDepositViewQrCode()
        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: module.view
        )
        module.output.didTapClose = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }
        bottomSheetViewController.present(fromViewController: navigationController)
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
            self?.finishRampFlow()
        }
        pickerModule.view.setupBackButton()

        navigationController.pushViewController(pickerModule.view, animated: true)
    }

    func openAssetPicker(assets: [RampAsset], rampLayoutItem: OnRampLayoutItem, onSelect: @escaping (RampAsset) -> Void) {
        let model = RampPickerAssetModel(assets: assets)

        let pickerModule = RampPickerAssembly.module(model: model, flow: flow)
        fireAssetPickerScreenViewEvent(assets: assets, rampLayoutItem: rampLayoutItem)
        pickerModule.output.didSelectAsset = { asset in
            onSelect(asset)
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

    func fireAssetPickerScreenViewEvent(assets: [RampAsset], rampLayoutItem: OnRampLayoutItem) {
        guard flow == .deposit else { return }
        let options = Set(assets.map(\.assetId))
        switch rampLayoutItem.type {
        case .fiat:
            fireDepositViewFiatChooseAsset(availableOptions: options)
        case .stablecoin:
            fireDepositViewChooseStablecoin(availableOptions: options)
        case .crypto:
            break
        }
    }

    func fireAssetPickerSelectionEvent(asset: RampAsset, rampLayoutItem: OnRampLayoutItem) {
        guard flow == .deposit else { return }
        switch rampLayoutItem.type {
        case .fiat:
            fireDepositClickFiatAsset(buyAsset: asset.assetId)
        case .stablecoin:
            fireDepositClickStablecoin(buyAsset: asset.assetId)
        case .crypto:
            break
        }
    }

    func openP2PExpress(asset: RampAsset, currencyCode: String) {
        logViewP2PIfNeeded(asset: asset)
        fireDepositViewP2pAlert()

        let walletAddress: String
        if asset.isTronNetwork {
            guard let address = wallet.tron?.address.base58 else { return }
            walletAddress = address
        } else if let address = try? self.wallet.friendlyAddress.toString() {
            walletAddress = address
        } else {
            return
        }

        let params = P2PExpressParams(
            wallet: walletAddress,
            assetId: nil,
            network: asset.network.lowercased(),
            cryptoCurrency: asset.symbol,
            fiatCurrency: currencyCode,
            amount: nil,
            requestNetwork: wallet.network,
            walletId: wallet.multichainWalletId
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

        coordinator.didTapOpen = { [weak self] url, _ in
            self?.fireDepositContinueToP2pMarket()
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
        flowContext.sellAsset = currency.code
        flowContext.paymentMethod = paymentMethod.type
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
        module.output.didLoadInitialMerchant = { [weak self] merchant in
            guard let merchant else { return }
            self?.fireDepositViewRampInsertAmount(providerName: merchant.title)
        }
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

            let amount = NSDecimalNumber(decimal: context.amount).floatValue
            self.fireDepositClickRampInsertAmountContinue(amount: amount, providerName: context.providerName)

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

        flowContext.amount = NSDecimalNumber(decimal: context.amount).floatValue
        flowContext.providerName = context.providerName
        fireDepositViewRampAlert()

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
        flowContext.amount = NSDecimalNumber(decimal: context.amount).floatValue
        flowContext.providerName = context.providerName
        fireDepositContinueToRampProvider(txId: context.txId)
        didTapOpenMerchant?(url)
    }

    func openCryptoPicker(
        assets: [OnRampLayoutCryptoMethod],
        onSelectCrypto: @escaping (OnRampLayoutCryptoMethod) -> Void
    ) {
        let cryptoItems: [CryptoPickerItem] = assets.map { method in
            let image: TKImage? = URL(string: method.image).map { .urlImage($0) }
            return CryptoPickerItem(
                identifier: method.assetId,
                symbol: method.symbol,
                networkName: method.networkName,
                network: method.network,
                networkImage: method.networkImage,
                image: image
            )
        }

        let model = RampPickerCryptoModel(items: cryptoItems, selectedId: nil)
        let pickerModule = RampPickerAssembly.module(model: model, flow: flow)
        pickerModule.output.didSelectCryptoItem = { item in
            let method = assets.first { $0.assetId == item.identifier }
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

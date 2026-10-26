import KeeperCore
import MoonPay
import TKAppInfo
import TKCoordinator
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class MoonPayRampCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didClose: (() -> Void)?
    var didTapOpenMerchant: ((URL) -> Void)?
    var didTapReceiveTokens: ((Wallet) -> Void)?

    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let multichainRampService: MultichainRampService
    private let viewModel: MoonPayRampViewModel
    private let merchantSource: MerchantRampSource
    private let moonPaySource: MoonPayRampSource?
    private let moonPay: MoonPayRampService?
    private let framePresenter = MoonPayRampFramePresenter()

    init(
        asset: MultichainAsset?,
        wallet: Wallet,
        router: NavigationControllerRouter,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        multichainRampService: MultichainRampService
    ) {
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.multichainRampService = multichainRampService
        let amountViewModel = AmountInputAssembly.swiftUIModule(
            sourceUnit: RemoteCurrency.default,
            destinationUnit: MoonPayRampAssetUnit(asset: asset),
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        let framePresenter = framePresenter
        let moonPay = Self.makeMoonPayService(framePresenter: framePresenter, multichainRampService: multichainRampService)
        self.moonPay = moonPay
        let merchantService = RampMerchantService(
            wallet: wallet,
            multichainRampService: multichainRampService,
            onRampService: keeperCoreMainAssembly.servicesAssembly.onRampService()
        )
        let merchantSource = MerchantRampSource(service: merchantService)
        let moonPaySource = moonPay.map { service in
            MoonPayRampSource(service: service) { [wallet] asset in
                asset.asset.chain.flatMap { wallet.multichainAddress(for: $0) }
            }
        }
        self.merchantSource = merchantSource
        self.moonPaySource = moonPaySource
        viewModel = MoonPayRampViewModel(
            asset: asset,
            currenciesService: keeperCoreMainAssembly.servicesAssembly.currenciesService(),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            merchant: merchantSource,
            moonPay: moonPaySource,
            loadDefaultAsset: { fiat in try await merchantService.defaultAsset(fiat: fiat) },
            amountViewModel: amountViewModel
        )
        super.init(router: router)

        viewModel.onClose = { [weak self] in
            self?.didClose?()
        }

        viewModel.onSelectCurrency = { [weak self] currencies, selected in
            self?.openCurrencyPicker(currencies: currencies, selected: selected)
        }
        viewModel.onSelectAsset = { [weak self] fiat in
            self?.openAssetPicker(preferredFiat: fiat)
        }
        viewModel.onFailure = { text in
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: text))
        }

        merchantSource.onSelectPaymentMethod = { [weak self] rows, selectedType in
            self?.openPaymentMethods(rows: rows, selectedType: selectedType)
        }
        merchantSource.onOpenP2P = { [weak self] asset, currencyCode in
            self?.openP2PExpress(asset: asset, currencyCode: currencyCode)
        }
        merchantSource.onOpenMerchant = { [weak self] url in
            self?.didTapOpenMerchant?(url)
        }

        moonPaySource?.onSelectPaymentMethod = { [weak self] rows, selectedType, cards, selectedCardID in
            self?.openPaymentMethods(
                rows: rows,
                selectedType: selectedType,
                savedCards: cards,
                selectedCardID: selectedCardID
            )
        }
        moonPaySource?.onAddCard = { [weak self] in
            self?.addCard()
        }
        moonPaySource?.onChallenge = { [weak self] url in
            self?.resolveChallenge(url)
        }
        moonPaySource?.onContinue = { [weak self] quote, methodTitle in
            self?.openPaymentStatus(quote: quote, methodTitle: methodTitle)
        }
    }

    override func start() {
        let viewController = MoonPayRampViewController(viewModel: viewModel)
        framePresenter.hostViewController = router.rootViewController
        router.rootViewController.setViewControllers([viewController], animated: false)
    }

    private static func makeMoonPayService(
        framePresenter: MoonPayRampFramePresenter,
        multichainRampService: MultichainRampService
    ) -> MoonPayRampService? {
        guard !UIApplication.shared.isAppStoreEnvironment else { return nil }
        let sandbox = TKAppPreferences.useMoonPaySandbox
        return MoonPayRampService(
            api: MoonPayPlatformAPI(environment: sandbox ? .sandbox : .production),
            makeSessionToken: { try await multichainRampService.createMoonPaySession(sandbox: sandbox) },
            framePresenter: framePresenter
        )
    }

    private func addCard() {
        guard let moonPay else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let card = try await moonPay.addCard()
                moonPaySource?.cardAdded(card)
            } catch let error as MoonPayRampError where error == .paymentCancelled {
                return
            } catch {
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: "\(error)"))
            }
        }
    }

    private func resolveChallenge(_ url: URL) {
        guard let moonPay else { return }
        Task { @MainActor [weak self] in
            await moonPay.resolveChallenge(url)
            self?.viewModel.reload()
        }
    }

    private func openPaymentStatus(quote: MoonPayBuyQuote, methodTitle: String) {
        guard let moonPay else { return }
        router.rootViewController.view.endEditing(true)
        let statusViewModel = MoonPayPaymentStatusViewModel(quote: quote, paymentTitle: methodTitle, service: moonPay)
        let viewController = MoonPayPaymentStatusViewController(viewModel: statusViewModel)
        statusViewModel.onClose = { [weak self, weak viewController] in
            viewController?.dismiss(animated: true) {
                self?.didClose?()
            }
        }
        statusViewModel.onRetry = { [weak self, weak viewController] retry in
            viewController?.dismiss(animated: true) {
                if retry == .anotherCard {
                    self?.viewModel.tapPaymentMethod()
                }
            }
        }
        if let sheet = viewController.sheetPresentationController {
            sheet.detents = [.large()]
        }
        viewController.modalPresentationStyle = .pageSheet
        router.rootViewController.present(viewController, animated: true)
    }

    private func openCurrencyPicker(currencies: [RemoteCurrency], selected: RemoteCurrency) {
        router.rootViewController.view.endEditing(true)
        let model = RampPickerCurrencyModel(currencies: currencies, selected: selected)
        let pickerModule = RampPickerAssembly.module(model: model, flow: .deposit)
        pickerModule.output.didSelectCurrency = { [weak self] currency in
            self?.viewModel.setCurrency(currency)
            self?.router.rootViewController.popViewController(animated: true)
        }
        pickerModule.output.didTapBack = { [weak self] in
            self?.router.rootViewController.popViewController(animated: true)
        }
        pickerModule.output.didTapClose = { [weak self] in
            self?.didClose?()
        }
        pickerModule.view.setupBackButton()
        router.rootViewController.pushViewController(pickerModule.view, animated: true)
    }

    private func openAssetPicker(preferredFiat: String) {
        router.rootViewController.view.endEditing(true)
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
                self?.router.rootViewController.popViewController(animated: true)
            }
        )
        module.output.didSelectAsset = { [weak self] asset in
            self?.viewModel.setAsset(asset)
            self?.router.rootViewController.popViewController(animated: true)
        }
        module.output.didFinish = { [weak self] in
            self?.didClose?()
        }
        router.rootViewController.pushViewController(module.view, animated: true)
    }

    private func openPaymentMethods(
        rows: [RampPaymentMethodRow],
        selectedType: String?,
        savedCards: [MoonPaySavedCard] = [],
        selectedCardID: String? = nil
    ) {
        router.rootViewController.view.endEditing(true)
        let paymentViewModel = MoonPayPaymentMethodViewModel(
            rows: rows,
            selectedType: selectedType,
            savedCards: savedCards,
            selectedCardID: selectedCardID
        )
        paymentViewModel.onSelect = { [weak self] type in
            self?.viewModel.setPaymentMethod(type)
            self?.router.rootViewController.popViewController(animated: true)
        }
        paymentViewModel.onSelectCard = { [weak self] id in
            self?.moonPaySource?.selectSavedCard(id)
            self?.router.rootViewController.popViewController(animated: true)
        }
        paymentViewModel.onSelectP2P = { [weak self] in
            self?.merchantSource.openP2P()
        }
        paymentViewModel.onCryptoDeposit = { [weak self] in
            guard let self else { return }
            didTapReceiveTokens?(wallet)
        }
        paymentViewModel.onBack = { [weak self] in
            self?.router.rootViewController.popViewController(animated: true)
        }
        paymentViewModel.onClose = { [weak self] in
            self?.didClose?()
        }
        let viewController = MoonPayPaymentMethodViewController(viewModel: paymentViewModel)
        router.rootViewController.pushViewController(viewController, animated: true)
    }

    private func openP2PExpress(asset: MultichainAsset, currencyCode: String) {
        let assetDetails = asset.asset
        guard let chain = assetDetails.chain,
              let walletAddress = wallet.multichainAddress(for: chain)
        else {
            Log.multichainRamp.w(
                "p2p express blocked - no wallet address for asset",
                extraInfo: ["assetId": assetDetails.assetId, "chain": assetDetails.chain?.rawValue ?? "unknown"]
            )
            return
        }

        let params = P2PExpressParams(
            wallet: walletAddress,
            assetId: assetDetails.assetId,
            network: nil,
            cryptoCurrency: nil,
            fiatCurrency: currencyCode,
            amount: nil,
            requestNetwork: wallet.network
        )
        let p2pModule = P2PExpressModule(
            dependencies: P2PExpressModule.Dependencies(
                onRampService: keeperCoreMainAssembly.servicesAssembly.onRampService()
            )
        )
        let coordinator = p2pModule.createP2PExpressCoordinator(
            router: ViewControllerRouter(rootViewController: router.rootViewController),
            params: params
        )
        coordinator.didTapOpen = { url, _ in
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        coordinator.didFailToCreateSession = { error in
            Log.multichainRamp.w(
                "p2p express session creation failed",
                error: error,
                extraInfo: ["assetId": assetDetails.assetId, "currency": currencyCode]
            )
            ToastPresenter.showToast(configuration: .init(title: error.localizedDescription))
        }
        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }
}

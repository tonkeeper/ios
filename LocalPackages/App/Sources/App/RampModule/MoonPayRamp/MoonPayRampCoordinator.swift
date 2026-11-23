import AppUI
import Combine
import KeeperCore
import MoonPay
import TKCoordinator
import TKCore
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
    private let moonPaySource: MoonPayRampSource
    private let moonPay: MoonPayRampService
    private let merchantService: RampMerchantService
    private let framePresenter = MoonPayRampFramePresenter()
    private let analytics: BuyCryptoAnalytics
    /// Waits for the amount screen's provider to be known, once per opening.
    private var amountShownObservation: AnyCancellable?
    /// What the merchant's Continue was for, taken at the tap.
    private var merchantPurchase: BuyCryptoPurchase?
    /// The payment status sheet on screen: its outcome is reported if the ramp goes first.
    private weak var paymentStatusViewModel: MoonPayPaymentStatusViewModel?
    /// Loaded once the payment method screen opens, so the provider sheet opens without a wait;
    /// nil once the load failed, which the next sheet opening repeats.
    private var merchantProvidersTask: (key: String, task: Task<[RampMerchantProvider]?, Never>)?
    private var isOpeningProviders = false
    /// Rebuilds the "via" line while the payment method screen is open, as the provider on screen,
    /// MoonPay's offer and the merchant change under it.
    private var providerHeaderObservation: AnyCancellable?
    private var providerHeaderRefresh: Task<Void, Never>?
    private var isProviderHeaderStale = false
    private weak var providerSheet: TKBottomSheetViewController?
    /// Set while a picked provider's methods go to the payment method screen on screen, instead of
    /// a new one.
    private weak var refreshingPaymentMethods: MoonPayPaymentMethodViewModel?
    /// Waits for a picked provider's methods to load.
    private var paymentMethodsLoading: AnyCancellable?
    /// The payment method screen on screen now: a removal reports to it even if the screen it
    /// started on was closed and opened again meanwhile.
    private weak var paymentMethodViewModel: MoonPayPaymentMethodViewModel?

    init(
        asset: MultichainAsset?,
        wallet: Wallet,
        router: NavigationControllerRouter,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        multichainRampService: MultichainRampService,
        reachabilityTracker: ReachabilityTracker,
        analytics: BuyCryptoAnalytics
    ) {
        self.wallet = wallet
        self.analytics = analytics
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
        self.merchantService = merchantService
        let merchantSource = MerchantRampSource(service: merchantService)
        let moonPaySource = MoonPayRampSource(
            service: moonPay,
            addressForAsset: { [wallet] asset in
                asset.asset.chain.flatMap { wallet.multichainAddress(for: $0) }
            },
            loadP2PMethod: { asset, fiat in
                try await merchantService.methods(asset: asset, fiat: fiat).rows.first(where: \.isP2P)
            }
        )
        self.merchantSource = merchantSource
        self.moonPaySource = moonPaySource
        viewModel = MoonPayRampViewModel(
            asset: asset,
            currenciesService: keeperCoreMainAssembly.servicesAssembly.currenciesService(),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            merchant: merchantSource,
            moonPay: moonPaySource,
            loadDefaultAsset: { fiat in try await merchantService.defaultAsset(fiat: fiat) },
            amountViewModel: amountViewModel,
            isNetworkUnavailable: { [weak reachabilityTracker] in
                reachabilityTracker?.state == .noInternetConnection
            }
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
        viewModel.onCryptoDeposit = { [weak self] in
            guard let self else { return }
            router.rootViewController.view.endEditing(true)
            didTapReceiveTokens?(wallet)
        }
        viewModel.onPriceDetails = { [weak self] in
            self?.openPriceDetails()
        }
        viewModel.onOffline = {
            ToastPresenter.showToast(configuration: .warning(text: TKLocales.ConnectionStatus.noInternet))
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
        merchantSource.onContinue = { [weak self] in
            guard let self else { return }
            // Taken at the tap: the merchant or the method may change while its page is requested.
            merchantPurchase = viewModel.analyticsPurchase?.with(mode: .merchant)
            if let merchantPurchase {
                analytics.continued(merchantPurchase)
            }
        }
        merchantSource.onOpenMerchant = { [weak self] url, txId in
            guard let self else { return }
            if let merchantPurchase {
                analytics.toProvider(merchantPurchase, txId: txId)
            }
            didTapOpenMerchant?(url)
        }

        moonPaySource.onSelectPaymentMethod = { [weak self] rows, selectedType, cards, selectedCardID in
            self?.openPaymentMethods(
                rows: rows,
                selectedType: selectedType,
                savedCards: cards,
                selectedCardID: selectedCardID
            )
        }
        moonPaySource.onOpenP2P = { [weak self] asset, currencyCode in
            self?.openP2PExpress(asset: asset, currencyCode: currencyCode)
        }
        moonPaySource.onAddCard = { [weak self] in
            self?.addCard()
        }
        moonPaySource.onChallenge = { [weak self] url in
            self?.resolveChallenge(url)
        }
        moonPaySource.onContinue = { [weak self] quote, methodTitle in
            guard let self else { return }
            // Continue that starts the payment: a tap that only opens a step before it, such as
            // the sign-in, a new card or a check, is not counted.
            if let purchase = viewModel.analyticsPurchase?.with(mode: .headless) {
                analytics.continued(purchase)
            }
            openPaymentStatus(
                quote: quote,
                methodTitle: methodTitle,
                txId: MoonPayRampService.newExternalTransactionId()
            )
        }
        moonPaySource.onApplePayPressed = { [weak self] quote, methodTitle, updates, txId in
            guard let self else { return }
            // The Apple Pay button stands in for Continue.
            if let purchase = viewModel.analyticsPurchase?.with(mode: .headless) {
                analytics.continued(purchase)
            }
            openPaymentStatus(quote: quote, methodTitle: methodTitle, txId: txId, updates: updates)
        }
    }

    /// Call once the ramp screen is gone, whichever way it went (a close or a swipe down): the
    /// Apple Pay button's payment stream is held in a cycle that only its end breaks.
    func tearDown() {
        paymentStatusViewModel?.sheetDidClose()
        viewModel.tearDown()
        moonPaySource.deactivate()
        merchantSource.deactivate()
    }

    override func start() {
        analytics.started()
        amountShownObservation = viewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reportAmountShownIfReady()
            }
        let viewController = MoonPayRampViewController(viewModel: viewModel)
        framePresenter.hostViewController = router.rootViewController
        router.rootViewController.setViewControllers([viewController], animated: false)
    }

    private func reportAmountShownIfReady() {
        guard let purchase = viewModel.shownPurchase else { return }
        analytics.amountShown(purchase)
        amountShownObservation = nil
    }

    private static func makeMoonPayService(
        framePresenter: MoonPayRampFramePresenter,
        multichainRampService: MultichainRampService
    ) -> MoonPayRampService {
        let sandbox = TKAppPreferences.useMoonPaySandbox
        return MoonPayRampService(
            api: MoonPayPlatformAPI(environment: sandbox ? .sandbox : .production),
            makeSessionToken: { try await multichainRampService.createMoonPaySession(sandbox: sandbox) },
            loadPaymentMethodInfo: { try await multichainRampService.getMoonPayPaymentMethods() },
            framePresenter: framePresenter
        )
    }

    private func addCard() {
        let moonPay = moonPay
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let card = try await moonPay.addCard()
                moonPaySource.cardAdded(card)
            } catch let error as MoonPayRampError where error == .paymentCancelled {
                return
            } catch {
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: "\(error)"))
            }
        }
    }

    private func resolveChallenge(_ url: URL) {
        let moonPay = moonPay
        Task { @MainActor [weak self] in
            await moonPay.resolveChallenge(url)
            self?.viewModel.reload()
        }
    }

    /// `updates` belong to a payment that already started on the ramp screen; without them the
    /// status screen opens the payment frame itself.
    private func openPaymentStatus(
        quote: MoonPayBuyQuote,
        methodTitle: String,
        txId: String,
        updates: AsyncStream<MoonPayPaymentUpdate>? = nil
    ) {
        let moonPay = moonPay
        let analytics = analytics
        let purchase = viewModel.analyticsPurchase?.with(mode: .headless)
        if let purchase {
            analytics.toProvider(purchase, txId: txId)
        }
        router.rootViewController.view.endEditing(true)
        weak var openedSheet: MoonPayPaymentStatusViewModel?
        let statusViewModel = MoonPayPaymentStatusViewModel(
            quote: quote,
            paymentTitle: methodTitle,
            // Named as on the ramp screen, network included, and rounded: "17.03 USDT (TON)".
            formatReceived: viewModel.asset.map { asset in
                let label = MoonPayRampViewModel.assetLabel(for: asset)
                return { "\(MoonPayRampViewModel.formatDisplayAmount($0)) \(label)" }
            },
            titleForMethod: { [weak moonPaySource] in moonPaySource?.title(forMethodType: $0) },
            // Apple Pay's updates begin with the press inside MoonPay's button.
            isPaymentOpened: updates != nil
        ) {
            updates ?? moonPay.pay(quote: quote, externalTransactionId: txId) {
                openedSheet?.paymentDidOpen()
            }
        }
        openedSheet = statusViewModel
        paymentStatusViewModel = statusViewModel
        statusViewModel.onOutcome = { outcome, failureReason in
            guard let purchase else { return }
            analytics.result(purchase, txId: txId, outcome: outcome, failureReason: failureReason)
        }
        // Scrolls once the fees, opened, take more than the screen leaves.
        let content = TKBottomSheetScrollHostingController(
            header: TKBottomSheetHeaderConfiguration(
                title: .title(title: TKLocales.Ramp.Moonpay.Status.title),
                rightButton: .close(action: { [weak statusViewModel] _ in statusViewModel?.close() }),
                contentInsets: UIEdgeInsets(top: 16, left: 16, bottom: 8, right: 16)
            )
        ) {
            MoonPayPaymentStatusContent(viewModel: statusViewModel)
        }
        let sheet = TKBottomSheetViewController(contentViewController: content)
        // A swipe down closes the sheet without its close button.
        sheet.didClose = { [weak statusViewModel] _ in
            statusViewModel?.sheetDidClose()
        }
        statusViewModel.onClose = { [weak self, weak sheet] in
            sheet?.dismiss {
                self?.didClose?()
            }
        }
        statusViewModel.onCancel = { [weak sheet] in
            guard let sheet else { return }
            // A frame or challenge above the sheet may still be closing, and UIKit ignores a
            // dismiss during a transition; the sheet's dismiss closes whatever is above it too.
            let navigation = sheet.navigationController
            let transition = navigation?.presentedViewController?.transitionCoordinator
                ?? navigation?.transitionCoordinator
            if let transition {
                transition.animate(alongsideTransition: nil) { [weak sheet] _ in sheet?.dismiss() }
            } else {
                sheet.dismiss()
            }
        }
        statusViewModel.onRetry = { [weak self, weak sheet] retry in
            sheet?.dismiss {
                switch retry {
                case .anotherCard:
                    self?.viewModel.tapPaymentMethod()
                case .changeAmount:
                    self?.viewModel.focusAmount()
                case .again:
                    break
                }
            }
        }
        statusViewModel.start()
        sheet.present(fromViewController: router.rootViewController.topPresentedViewController())
    }

    /// Follows the quote on screen while open: a refreshed quote updates its rows, and the sheet
    /// closes once the screen has no quote to break down.
    private func openPriceDetails() {
        let navigation = router.rootViewController
        guard navigation.topViewController is MoonPayRampViewController,
              navigation.presentedViewController == nil,
              let state = viewModel.priceDetailsState
        else { return }
        // The keyboard stays down after the sheet: the user taps the amount to change it.
        navigation.view.endEditing(true)
        weak var presentedSheet: TKBottomSheetViewController?
        // Scrolls and re-measures, so a refreshed quote with another set of fees fits.
        let content = TKBottomSheetScrollHostingController(
            header: TKBottomSheetHeaderConfiguration(
                title: .title(title: TKLocales.Ramp.Moonpay.PriceDetails.title),
                rightButton: .close(),
                contentInsets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            )
        ) {
            MoonPayPriceDetailsScreen(viewModel: viewModel, opened: state) {
                presentedSheet?.dismiss()
            }
        }
        let sheet = TKBottomSheetViewController(contentViewController: content)
        presentedSheet = sheet
        sheet.present(fromViewController: navigation.topPresentedViewController())
    }

    private func openCurrencyPicker(currencies: [RemoteCurrency], selected: RemoteCurrency) {
        // A currency list loaded again after a failed start arrives late: whatever opened over
        // the Buy screen meanwhile (a payment, a sheet, another screen) keeps the stage.
        let navigation = router.rootViewController
        guard navigation.topViewController is MoonPayRampViewController,
              navigation.presentedViewController == nil
        else { return }
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
        // Once per opening: the list reloads on a pull or a filter cleared.
        var isListReported = false
        model.onListLoaded = { [weak self] assetIds in
            Task { @MainActor [weak self] in
                guard let self, !isListReported else { return }
                isListReported = true
                analytics.assetListShown(assetIds)
            }
        }
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
            self?.analytics.assetPicked(asset.asset.assetId)
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
        if let refreshing = refreshingPaymentMethods {
            refreshingPaymentMethods = nil
            refreshing.providerName = viewModel.providerName
            refreshing.update(
                rows: rows,
                selectedType: selectedType,
                savedCards: savedCards,
                selectedCardID: selectedCardID,
                canDeleteCards: moonPaySource.canDeleteCards,
                removingCardIDs: moonPaySource.removingCardIDs
            )
            return
        }
        router.rootViewController.view.endEditing(true)
        let paymentViewModel = MoonPayPaymentMethodViewModel(
            rows: rows,
            selectedType: selectedType,
            savedCards: savedCards,
            selectedCardID: selectedCardID,
            canDeleteCards: moonPaySource.canDeleteCards,
            removingCardIDs: moonPaySource.removingCardIDs
        )
        paymentMethodViewModel = paymentViewModel
        paymentViewModel.providerName = viewModel.providerName
        let analyticsScope = viewModel.asset.map { (assetId: $0.asset.assetId, fiat: viewModel.fiatCode) }
        if let analyticsScope {
            var methods = rows.map(\.type)
            if !savedCards.isEmpty {
                methods.append(BuyCryptoAnalytics.savedCardMethod)
            }
            analytics.methodsShown(assetId: analyticsScope.assetId, fiat: analyticsScope.fiat, methods: methods)
        }
        // The first pick of this opening.
        var isPickReported = false
        var isP2PPickReported = false
        let reportPick: (String) -> Void = { [analytics] method in
            guard let analyticsScope, !isPickReported else { return }
            isPickReported = true
            analytics.methodPicked(assetId: analyticsScope.assetId, fiat: analyticsScope.fiat, method: method)
        }
        let reportP2PPick: (String) -> Void = { [analytics] method in
            guard let analyticsScope, !isPickReported, !isP2PPickReported else { return }
            isP2PPickReported = true
            analytics.methodPicked(assetId: analyticsScope.assetId, fiat: analyticsScope.fiat, method: method)
        }
        if viewModel.asset != nil {
            merchantProvidersTask = nil
            paymentViewModel.onTapProvider = { [weak self, weak paymentViewModel] in
                guard let paymentViewModel else { return }
                self?.openProviders(for: paymentViewModel)
            }
            providerHeaderObservation = viewModel.objectWillChange.sink { [weak self] _ in
                // Back on Buy, its changes have no header to update.
                guard let self, paymentMethodViewModel != nil else { return }
                refreshProviderHeader()
            }
            refreshProviderHeader()
        }
        paymentViewModel.onSelect = { [weak self] type in
            reportPick(type)
            self?.viewModel.setPaymentMethod(type)
            self?.router.rootViewController.popViewController(animated: true)
        }
        paymentViewModel.onSelectCard = { [weak self] id in
            reportPick(BuyCryptoAnalytics.savedCardMethod)
            self?.moonPaySource.selectSavedCard(id)
            self?.router.rootViewController.popViewController(animated: true)
        }
        paymentViewModel.onRemoveCard = { [weak self] card in
            guard let moonPaySource = self?.moonPaySource else { return }
            Task { @MainActor [weak self] in
                do {
                    try await moonPaySource.deleteCard(card.id)
                    self?.paymentMethodViewModel?.cardRemoved(card.id)
                    ToastPresenter.showToast(configuration: .confirmed(text: TKLocales.Ramp.Moonpay.Card.removed))
                } catch {
                    self?.paymentMethodViewModel?.cardRemovalFailed(card.id)
                    // The user closed MoonPay's sign-in on purpose: nothing to report.
                    guard error as? MoonPayRampError != .verificationCancelled else { return }
                    Log.multichainRamp.w("moonpay card removal failed", error: error)
                    ToastPresenter.showToast(configuration: .defaultConfiguration(text: TKLocales.Errors.unknown))
                }
            }
        }
        paymentViewModel.onSelectP2P = { [weak self] in
            guard let self, let asset = viewModel.asset else { return }
            if let p2p = rows.first(where: \.isP2P) {
                // P2P opens over this screen, which stays: a pick after it is reported too.
                reportP2PPick(p2p.type)
            }
            openP2PExpress(asset: asset, currencyCode: viewModel.fiatCode)
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

    // MARK: - Provider

    /// The merchants that sell the asset in the currency; nil when they failed to load. Cached for
    /// the asset and currency, which may change while the payment method screen stays. A failed
    /// load is repeated only with `retriesFailure`, so a header refresh does not call the backend
    /// on every change.
    private func merchantProviders(retriesFailure: Bool = true) async -> [RampMerchantProvider]? {
        guard let asset = viewModel.asset else { return [] }
        let fiat = viewModel.fiatCode
        let key = providersKey
        if let cached = merchantProvidersTask, cached.key == key {
            let merchants = await cached.task.value
            if merchants != nil || !retriesFailure { return merchants }
        }
        let task = Task<[RampMerchantProvider]?, Never> { [weak self] in
            guard let self else { return [] }
            do {
                return try await merchantService.providers(asset: asset, fiat: fiat)
            } catch {
                Log.multichainRamp.w("ramp providers failed", error: error)
                return nil
            }
        }
        merchantProvidersTask = (key, task)
        return await task.value
    }

    /// The asset and currency the providers are for.
    private var providersKey: String {
        "\(viewModel.asset?.asset.assetId ?? "")|\(viewModel.fiatCode)"
    }

    /// The rows of the provider sheet and the facts they were built on.
    private struct ProviderList {
        var options: [RampProviderOption]
        /// False when the merchants failed to load.
        var isComplete: Bool
        var key: String
        /// One reading for the rows and the checkmark, which would miss every row if they read it
        /// at different times.
        var offersMoonPay: Bool
    }

    /// Loads again while the asset or currency changes during the load, so the result is the
    /// current one's, as long as `isOpen` says the payment method screen it is for is still there.
    /// The screen's view model is held weakly for that: a strong one would keep it alive.
    /// `cachedOnly` takes MoonPay's method titles as loaded so far, without asking the backend.
    private func providerList(
        retriesFailure: Bool = true,
        cachedOnly: Bool = false,
        while isOpen: () -> Bool
    ) async -> ProviderList {
        var list = await providerList(for: providersKey, retriesFailure: retriesFailure, cachedOnly: cachedOnly)
        for _ in 0 ..< Self.providerReloadLimit where list.key != providersKey && isOpen() {
            list = await providerList(for: providersKey, retriesFailure: retriesFailure, cachedOnly: cachedOnly)
        }
        return list
    }

    private static let providerReloadLimit = 3

    /// MoonPay where it is offered, then the merchants. MoonPay's widget is one of them only where
    /// the native MoonPay is not offered: two MoonPay rows would read the same.
    private func providerList(for key: String, retriesFailure: Bool, cachedOnly: Bool) async -> ProviderList {
        let loaded = await merchantProviders(retriesFailure: retriesFailure)
        let merchants = loaded ?? []
        let offersMoonPay = viewModel.isMoonPayOffered
        let moonPayTitles = offersMoonPay ? await moonPaySource.methodTitles(cachedOnly: cachedOnly) : []
        var options: [RampProviderOption] = []
        if offersMoonPay {
            options.append(RampProviderOption(
                kind: .moonPay,
                title: MoonPayRampViewModel.moonPayName,
                subtitle: moonPayTitles.joined(separator: ", "),
                image: .image(.TKUIKit.Artwork.Providers.moonpay)
            ))
        }
        options += merchants.filter { !(offersMoonPay && $0.isMoonPay) }.map { merchant in
            RampProviderOption(
                kind: .merchant(id: merchant.id, title: merchant.title),
                title: merchant.title,
                subtitle: merchant.methodTitles.joined(separator: ", "),
                image: .url(merchant.imageURL)
            )
        }
        return ProviderList(options: options, isComplete: loaded != nil, key: key, offersMoonPay: offersMoonPay)
    }

    /// Without a merchant chosen yet, such as with P2P selected or before the merchants load, the
    /// first merchant listed stands for the provider, as it is the one picked first.
    /// The line stays tappable after a failed load, as the tap loads the providers again, and while
    /// MoonPay's widget stands in for the native MoonPay, as picking MoonPay tries the native one.
    private func updateProviderHeader(_ paymentViewModel: MoonPayPaymentMethodViewModel, list: ProviderList) {
        paymentViewModel.providerName = viewModel.providerName ?? list.options.first { option in
            if case .merchant = option.kind { return true }
            return false
        }?.title
        let widgetStandsIn = viewModel.provider != .moonPay
            && currentProviderID(offersMoonPay: list.offersMoonPay) == RampProviderOption.Kind.moonPay.id
        paymentViewModel.isProviderSwitchable = list.options.count > 1 || !list.isComplete || widgetStandsIn
    }

    /// Coalesces the changes of one pass, and runs once more for changes that came during a run.
    /// objectWillChange comes before the change, so the run starts on the next turn.
    /// Works on the payment method screen open when it runs: one reopened during a run gets the
    /// next run.
    private func refreshProviderHeader() {
        isProviderHeaderStale = true
        guard providerHeaderRefresh == nil else { return }
        providerHeaderRefresh = Task { @MainActor [weak self] in
            defer { self?.providerHeaderRefresh = nil }
            while let self, isProviderHeaderStale {
                isProviderHeaderStale = false
                await Task.yield()
                weak let screen = paymentMethodViewModel
                guard screen != nil else { return }
                let list = await providerList(retriesFailure: false, cachedOnly: true) { screen != nil }
                guard let current = paymentMethodViewModel else { return }
                guard current === screen else {
                    isProviderHeaderStale = true
                    continue
                }
                updateProviderHeader(current, list: list)
            }
        }
    }

    /// The provider with the checkmark: the one Continue goes to, except that MoonPay's widget on
    /// screen, such as after a native MoonPay fallback, checks the MoonPay row where the native
    /// MoonPay is offered. The sheet lists no second MoonPay row for it, and picking MoonPay there
    /// tries the native one again. The backend titles the widget "MoonPay", as the header reads.
    private func currentProviderID(offersMoonPay: Bool) -> String? {
        switch viewModel.provider {
        case .moonPay:
            return RampProviderOption.Kind.moonPay.id
        case .merchant:
            guard let id = viewModel.merchantId else { return nil }
            if offersMoonPay, RampMerchantProvider.isMoonPay(merchantId: id) {
                return RampProviderOption.Kind.moonPay.id
            }
            return RampProviderOption.Kind.merchant(id: id, title: "").id
        }
    }

    /// The provider the user picked: a best-rate merchant tapped in the sheet becomes the pick.
    private var pickedProviderID: String? {
        if let preferred = merchantSource.preferredMerchant {
            return RampProviderOption.Kind.merchant(id: preferred.id, title: "").id
        }
        return viewModel.provider == .moonPay ? RampProviderOption.Kind.moonPay.id : nil
    }

    private func openProviders(for paymentViewModel: MoonPayPaymentMethodViewModel) {
        guard providerSheet == nil, !isOpeningProviders else { return }
        isOpeningProviders = true
        Task { @MainActor [weak self, weak paymentViewModel] in
            guard let self else { return }
            defer { isOpeningProviders = false }
            let list = await providerList { paymentViewModel != nil }
            // The screen the sheet belongs to may have closed meanwhile.
            guard let paymentViewModel, paymentMethodViewModel === paymentViewModel else { return }
            updateProviderHeader(paymentViewModel, list: list)
            if !list.isComplete {
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: TKLocales.Errors.unknown))
            }
            guard providerSheet == nil, !list.options.isEmpty else { return }
            presentProviders(list, for: paymentViewModel)
        }
    }

    private func presentProviders(_ list: ProviderList, for paymentViewModel: MoonPayPaymentMethodViewModel) {
        let options = list.options
        let currentID = currentProviderID(offersMoonPay: list.offersMoonPay)
        let pickedID = pickedProviderID
        let state = MoonPayProviderViewState(rows: options.map { option in
            .init(
                id: option.kind.id,
                title: option.title,
                subtitle: option.subtitle,
                image: option.image,
                isSelected: option.kind.id == currentID
            )
        })
        let content = TKBottomSheetHostingController(
            content: MoonPayProviderView(state: state) { [weak self, weak paymentViewModel] id in
                guard let option = options.first(where: { $0.kind.id == id }) else { return }
                // The picked provider again changes nothing, unless its methods failed to load.
                let changesNothing = id == pickedID && paymentViewModel?.hasNoRows == false
                self?.selectProvider(option, changesNothing: changesNothing)
            },
            headerConfiguration: TKBottomSheetHeaderConfiguration(
                title: .title(title: TKLocales.Ramp.ProviderPicker.title),
                rightButton: .close(),
                contentInsets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            )
        )
        let sheet = TKBottomSheetViewController(contentViewController: content)
        providerSheet = sheet
        sheet.present(fromViewController: router.rootViewController.topPresentedViewController())
    }

    /// The Buy screen takes the provider's methods and quote, and the payment method screen stays
    /// to list them once they are loaded.
    private func selectProvider(_ option: RampProviderOption, changesNothing: Bool) {
        providerSheet?.dismiss { [weak self] in
            guard let self, !changesNothing else { return }
            switch option.kind {
            case .moonPay:
                viewModel.selectMoonPay()
            case let .merchant(id, title):
                viewModel.selectMerchant(id: id, title: title)
            }
            guard let paymentViewModel = paymentMethodViewModel else { return }
            paymentViewModel.providerName = viewModel.providerName
            paymentViewModel.isLoading = true
            refreshPaymentMethods(paymentViewModel)
        }
    }

    private func refreshPaymentMethods(_ paymentViewModel: MoonPayPaymentMethodViewModel) {
        paymentMethodsLoading = nil
        guard viewModel.isLoadingPaymentMethods else {
            listPaymentMethods(on: paymentViewModel)
            return
        }
        // A sink, not `objectWillChange.values`: the view model sends several changes in one pass,
        // which the async sequence takes as output it never asked for, and traps.
        paymentMethodsLoading = viewModel.objectWillChange.sink { [weak self, weak paymentViewModel] _ in
            // objectWillChange comes before the change; look once it has landed.
            Task { @MainActor [weak self, weak paymentViewModel] in
                guard let self, let paymentViewModel, paymentMethodsLoading != nil,
                      !viewModel.isLoadingPaymentMethods
                else { return }
                paymentMethodsLoading = nil
                listPaymentMethods(on: paymentViewModel)
            }
        }
    }

    private func listPaymentMethods(on paymentViewModel: MoonPayPaymentMethodViewModel) {
        guard paymentMethodViewModel === paymentViewModel else { return }
        refreshingPaymentMethods = paymentViewModel
        viewModel.tapPaymentMethod()
        refreshingPaymentMethods = nil
        paymentViewModel.isLoading = false
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
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: TKLocales.Errors.unknown))
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
        coordinator.didTapOpen = { [analytics] url, _ in
            // As on Add Funds: the P2P market counts once its link is tapped.
            analytics.toP2P()
            guard UIApplication.shared.canOpenURL(url) else {
                Log.multichainRamp.w(
                    "p2p express deeplink cannot be opened",
                    extraInfo: ["assetId": assetDetails.assetId, "scheme": url.scheme ?? "none"]
                )
                ToastPresenter.showToast(configuration: .defaultConfiguration(text: TKLocales.Errors.unknown))
                return
            }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
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

/// A row of the provider sheet.
private struct RampProviderOption {
    enum Kind {
        case moonPay
        case merchant(id: String, title: String)

        var id: String {
            switch self {
            case .moonPay: "moonpay"
            case let .merchant(id, _): "merchant:\(id)"
            }
        }
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let image: AssetAvatarViewImageSource
}

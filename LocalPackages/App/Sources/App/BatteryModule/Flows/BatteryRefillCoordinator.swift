import AppUI
import BigInt
import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

final class BatteryRefillCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didOpenRefundURL: ((_ url: URL, _ title: String) -> Void)?
    var didRechargeSuccess: (() -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?

    private var isNeedToOpenRecharge: Bool = false

    private let wallet: Wallet
    private weak var refillInput: BatteryRefillModuleInput?
    private var activeRechargeRouter: NavigationControllerRouter?
    private let rechargePickerRequest = BatteryRechargePickerRequest()
    private let jettonMasterAddress: Address?
    private let initiatedBy: InitiatedBy
    private let utm: UtmParameters
    private let analytics: BatteryAnalytics
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let promocodeStore: BatteryPromocodeStore
    private let batteryCryptoRechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider

    init(
        router: NavigationControllerRouter,
        wallet: Wallet,
        jettonMasterAddress: Address?,
        initiatedBy: InitiatedBy,
        analyticsSource: BatteryAnalyticsSource,
        utm: UtmParameters = .empty,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.wallet = wallet
        self.jettonMasterAddress = jettonMasterAddress
        self.initiatedBy = initiatedBy
        self.utm = utm
        self.analytics = BatteryAnalytics(
            source: analyticsSource,
            utm: utm,
            analyticsProvider: coreAssembly.analyticsProvider
        )
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.promocodeStore = keeperCoreMainAssembly.batteryAssembly.batteryPromocodeStore()
        self.batteryCryptoRechargeMethodsProvider = BatteryCryptoRechargeMethodsProvider(
            wallet: wallet,
            balanceService: keeperCoreMainAssembly.servicesAssembly.balanceService(),
            batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
            jettonService: keeperCoreMainAssembly.servicesAssembly.jettonService(),
            purchaseService: keeperCoreMainAssembly.batteryAssembly.batteryPurchaseService(),
            assetBalanceProvider: keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider
        )
        super.init(router: router)
    }

    override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
        analytics.logOpen()
        openBatteryRefill()
    }

    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        guard let walletTransferSignCoordinator = walletTransferSignCoordinator else { return false }
        walletTransferSignCoordinator.externalSignHandler?(sign)
        walletTransferSignCoordinator.externalSignHandler = nil
        return true
    }

    func didAppear() {
        if isNeedToOpenRecharge {
            isNeedToOpenRecharge = false
            openBatteryRechargeIfNeeded(rechargeMethodsProvider: batteryCryptoRechargeMethodsProvider, promocodeStore: promocodeStore)
        }
    }
}

private extension BatteryRefillCoordinator {
    func openBatteryRefill() {
        let module = BatteryRefillAssembly.module(
            wallet: wallet,
            promocodeStore: promocodeStore,
            rechargeMethodsProvider: batteryCryptoRechargeMethodsProvider,
            analytics: analytics,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        refillInput = module.input
        module.output.didTapSupportedTransactions = { [weak self] networks in
            guard let self else { return }
            openSupportedTransactions(wallet: wallet, networks: networks)
        }

        module.output.didFinish = { [weak self] in
            self?.didFinish?(self)
        }

        module.output.didTapRecharge = { [weak self] rechargeMethod in
            guard let self else { return }
            openRecharge(item: rechargeMethod, promocodeStore: promocodeStore)
        }

        module.output.didTapContinue = { [weak self] payload in
            self?.analytics.logSelect(payload.analyticsPurchase)
            self?.openConfirmation(payload: payload)
        }
        module.output.didTapAssetRecharge = { [weak self] asset, amount, promo in
            Task { @MainActor in self?.openAssetRecharge(asset: asset, amount: amount, promo: promo) }
        }
        module.output.didTapPayWith = { [weak self] methods, select in
            self?.openPayWith(methods: methods, select: select)
        }
        module.output.didOpenRefundURL = { [weak self] url, title in
            self?.didOpenRefundURL?(url, title)
        }

        router.push(viewController: module.view, animated: false, completion: { [weak self] in
            guard let self else { return }
            guard router.rootViewController.presentingViewController != nil else {
                self.isNeedToOpenRecharge = true
                return
            }

            openBatteryRechargeIfNeeded(
                rechargeMethodsProvider: batteryCryptoRechargeMethodsProvider,
                promocodeStore: promocodeStore
            )
        })
    }

    func openSupportedTransactions(wallet: Wallet, networks: BatteryNetworks) {
        let controller = BatteryRefillSupportedTransactionsAssembly.module(
            wallet: wallet,
            networks: networks,
            showsClose: router.rootViewController.presentingViewController != nil,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        router.push(viewController: controller)
    }

    func openRecharge(
        item: BatteryRefillRechargeMethodsModel.RechargeMethodItem,
        promocodeStore: BatteryPromocodeStore
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if case let .gift(token) = item {
                let module = BatteryRechargeAssembly.module(wallet: wallet, token: token, isGift: true, promocodeStore: promocodeStore, keeperCoreMainAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)
                module.output.didTapContinue = { [weak self] payload in
                    self?.analytics.logSelect(payload.analyticsPurchase)
                    self?.openConfirmation(payload: payload)
                }
                weak let input = module.input
                module.output.didSelectTokenPicker = { [weak self] token in
                    self?.openTokenPicker(token: token) { input?.setToken(token: $0) }
                }
                router.present(module.view)
                return
            }
            presentRecharge(item: item)
        }
    }

    @MainActor
    func openAssetRecharge(asset: BatteryRechargeAsset, amount: BigUInt?, promo: String? = nil) {
        presentRecharge(item: .asset(asset), amount: amount, optionID: amount == nil ? "custom" : nil, promo: promo)
    }

    @MainActor
    func presentRecharge(item: BatteryRefillRechargeMethodsModel.RechargeMethodItem, amount: BigUInt? = nil, optionID: String? = nil, promo: String? = nil) {
        if case let .asset(asset) = item, !asset.isReady { return }
        guard router.rootViewController.presentedViewController == nil, activeRechargeRouter?.rootViewController.presentingViewController == nil else { return }
        let navigation = TKNavigationController()
        navigation.setNavigationBarHidden(true, animated: false)
        let rechargeRouter = NavigationControllerRouter(rootViewController: navigation)
        activeRechargeRouter = rechargeRouter
        showRecharge(item: item, amount: amount, optionID: optionID, promo: promo, rechargeRouter: rechargeRouter)
        router.present(navigation, onDismiss: { [weak self, weak rechargeRouter] in
            guard let rechargeRouter else { return }
            self?.finishRecharge(rechargeRouter)
        })
    }

    @MainActor
    func showRecharge(item: BatteryRefillRechargeMethodsModel.RechargeMethodItem, amount: BigUInt? = nil, optionID: String? = nil, promo: String? = nil, rechargeRouter: NavigationControllerRouter) {
        switch item {
        case let .token(token):
            let module = BatteryRechargeAssembly.module(wallet: wallet, token: token, isGift: false, selectsCustomAmount: optionID == "custom", initialOptionID: optionID, promocodeStore: promocodeStore, keeperCoreMainAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)
            module.output.didTapContinue = { [weak self] payload in
                self?.analytics.logSelect(payload.analyticsPurchase)
                self?.openConfirmation(payload: payload)
            }
            module.output.didTapClose = { [weak self, weak rechargeRouter] in
                guard let rechargeRouter else { return }
                self?.closeRecharge(rechargeRouter)
            }
            weak let input = module.input
            weak let controller = module.view
            module.output.didSelectTokenPicker = { [weak self, weak rechargeRouter] token in
                guard let rechargeRouter, let controller else { return }
                self?.openRechargePicker(rechargeRouter: rechargeRouter, controller: controller, selectedID: token.identifier, optionID: { input?.selectedOptionID })
            }
            replaceRechargeController(module.view, rechargeRouter: rechargeRouter)
        case let .asset(asset):
            guard asset.isReady else { return }
            weak var rechargeController: UIViewController?
            let promocodeViewModel = BatteryPromocodeInputAssembly.module(wallet: wallet, promocodeStore: promocodeStore, keeperCoreMainAssembly: keeperCoreMainAssembly)
            let batteryService = keeperCoreMainAssembly.batteryAssembly.batteryService()
            let balanceLoader = keeperCoreMainAssembly.loadersAssembly.balanceLoader
            let assetBalanceProvider = keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider
            let currencyStore = keeperCoreMainAssembly.storesAssembly.currencyStore
            let model = BatteryAssetRechargeViewModel(
                source: asset, amount: amount, promo: promo, wallet: wallet,
                purchaser: keeperCoreMainAssembly.batteryAssembly.batteryPurchaser(multichainAssembly: keeperCoreMainAssembly.multichainAssembly),
                loadBatteryBalance: { [wallet] in try await batteryService.loadBatteryBalance(wallet: wallet).balanceDecimalNumber },
                currency: { currencyStore.getState() },
                isSecureMode: { [appSettingsStore = keeperCoreMainAssembly.storesAssembly.appSettingsStore] in appSettingsStore.getState().isSecureMode },
                refresh: { [wallet, weak refillInput] in
                    await balanceLoader.reloadBalance(wallet: wallet, priority: .userVisible)
                    _ = await assetBalanceProvider.reloadAsset(for: asset.asset.asset.assetId, wallet: wallet, includingHidden: true)
                    refillInput?.refresh()
                },
                initialOptionID: optionID,
                passcodeProvider: { [weak self, weak rechargeRouter] in
                    guard let self, let rechargeRouter else { return nil }
                    return await PasscodeInputCoordinator.getPasscode(parentCoordinator: self, parentRouter: rechargeRouter, mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess, securityStore: keeperCoreMainAssembly.storesAssembly.securityStore, analyticsProvider: coreAssembly.analyticsProvider, reason: .topUpBattery)
                },
                onSelect: { [weak self] purchase in self?.analytics.logSelect(purchase) },
                onCredit: { [analytics] purchase in analytics.logSuccess(purchase) },
                onSuccess: { [weak self, weak rechargeRouter] _ in
                    guard let self, let rechargeRouter, rechargeRouter.rootViewController.topViewController === rechargeController, rechargeRouter.rootViewController.presentingViewController != nil else { return }
                    closeRecharge(rechargeRouter) { [weak self] in
                        ToastPresenter.showToast(configuration: .defaultConfiguration(text: TKLocales.Battery.Refill.Toast.recharged))
                        self?.didRechargeSuccess?()
                    }
                },
                onClose: { [weak self, weak rechargeRouter] in
                    guard let rechargeRouter else { return }
                    self?.closeRecharge(rechargeRouter)
                }
            )
            let controller = BatteryAssetRechargeHostingViewController(
                model: model,
                promocodeViewModel: promocodeViewModel,
                showsPromocode: !keeperCoreMainAssembly.configurationAssembly.configuration.isDisableBatteryPromoModule(network: wallet.network)
            )
            rechargeController = controller
            model.willContinue = { [weak self] in self?.rechargePickerRequest.cancel() }
            model.onSelectAsset = { [weak self, weak rechargeRouter, weak controller, weak model] in
                guard let rechargeRouter, let controller else { return }
                self?.openRechargePicker(rechargeRouter: rechargeRouter, controller: controller, selectedID: asset.method.assetId, optionID: { [weak model] in model?.selectedOptionID })
            }
            replaceRechargeController(controller, rechargeRouter: rechargeRouter)
        case .gift: break
        }
    }

    @MainActor
    func replaceRechargeController(_ controller: UIViewController, rechargeRouter: NavigationControllerRouter) {
        (rechargeRouter.rootViewController.topViewController as? BatteryAssetRechargeHostingViewController)?.stopForAssetChange()
        rechargeRouter.rootViewController.view.endEditing(true)
        rechargeRouter.rootViewController.setViewControllers([controller], animated: false)
    }

    @MainActor
    func closeRecharge(_ rechargeRouter: NavigationControllerRouter, completion: (() -> Void)? = nil) {
        rechargePickerRequest.cancel()
        rechargeRouter.rootViewController.dismiss(animated: true) { [weak self, weak rechargeRouter] in
            if let rechargeRouter { self?.finishRecharge(rechargeRouter) }
            completion?()
        }
    }

    @MainActor
    func finishRecharge(_ rechargeRouter: NavigationControllerRouter) {
        guard activeRechargeRouter === rechargeRouter else { return }
        rechargePickerRequest.cancel()
        activeRechargeRouter = nil
        refillInput?.refresh()
    }

    @MainActor
    func openRechargePicker(rechargeRouter: NavigationControllerRouter, controller: UIViewController, selectedID: String, optionID: @escaping () -> String?) {
        weak let input = refillInput
        rechargePickerRequest.load(onLoadingChange: { [weak controller] loading in
            (controller as? BatteryRechargePickerHosting)?.setPaymentMethodsLoading(loading)
        }, load: {
            await input?.loadRechargeOptions(selectedID: selectedID) ?? []
        }) { [weak self, weak rechargeRouter, weak controller] options in
            guard let self, let rechargeRouter, let controller else { return }
            guard (controller as? BatteryAssetRechargeHostingViewController)?.allowsAssetSelection != false else { return }
            guard activeRechargeRouter === rechargeRouter, rechargeRouter.rootViewController.topViewController === controller, rechargeRouter.rootViewController.presentingViewController != nil, rechargeRouter.rootViewController.presentedViewController == nil, !options.isEmpty else { return }
            openPayWith(methods: options.map(\.presentation), presentingController: rechargeRouter.rootViewController) { [weak self, weak rechargeRouter, weak controller] id in
                guard let self, let rechargeRouter, let controller, id != selectedID, activeRechargeRouter === rechargeRouter, rechargeRouter.rootViewController.topViewController === controller, rechargeRouter.rootViewController.presentingViewController != nil, let option = options.first(where: { $0.presentation.id == id }) else { return }
                guard (controller as? BatteryAssetRechargeHostingViewController)?.allowsAssetSelection != false else { return }
                switch option.destination {
                case .appStore:
                    refillInput?.selectPaymentMethod(id: id)
                    closeRecharge(rechargeRouter)
                case let .crypto(item):
                    if case let .asset(asset) = item, !asset.isReady { return }
                    refillInput?.selectPaymentMethod(id: id)
                    showRecharge(item: item, optionID: optionID() ?? "custom", rechargeRouter: rechargeRouter)
                }
            }
        }
    }

    func openPayWith(
        methods: [BatteryRefillViewState.PaymentMethod],
        presentingController: UIViewController? = nil,
        select: @escaping (String) -> Void
    ) {
        weak var bottomSheetViewController: TKBottomSheetViewController?
        let contentViewController = TKBottomSheetScrollHostingController(
            header: TKBottomSheetHeaderConfiguration(
                title: .title(title: TKLocales.Battery.Refill.payWithTitle),
                rightButton: .close()
            )
        ) {
            BatteryPayWithView(
                methods: methods,
                onSelect: { id in
                    bottomSheetViewController?.dismiss { select(id) }
                },
                onOtherTokens: { [weak self] in
                    bottomSheetViewController?.dismiss(completion: Self.handOff(from: presentingController) { presentingController in
                        self?.openOtherTokens(methods: methods, presentingController: presentingController, select: select)
                    })
                }
            )
        }
        let sheet = TKBottomSheetViewController(contentViewController: contentViewController)
        bottomSheetViewController = sheet
        sheet.present(fromViewController: presentingController ?? router.rootViewController.topPresentedViewController())
    }

    /// Opens the next sheet once the last one has gone, unless the recharge screen it was shown on has closed meanwhile.
    static func handOff(
        from presentingController: UIViewController?,
        _ open: @escaping (UIViewController?) -> Void
    ) -> () -> Void {
        guard let presentingController else { return { open(nil) } }
        return { [weak presentingController] in
            guard let presentingController, presentingController.presentingViewController != nil else { return }
            open(presentingController)
        }
    }

    /// Takes the Pay with sheet's place, so Back brings that sheet back instead of stacking one on another.
    func openOtherTokens(
        methods: [BatteryRefillViewState.PaymentMethod],
        presentingController: UIViewController?,
        select: @escaping (String) -> Void
    ) {
        weak var bottomSheetViewController: TKBottomSheetViewController?
        let contentViewController = TKBottomSheetScrollHostingController(
            header: TKBottomSheetHeaderConfiguration(
                title: .title(title: TKLocales.Battery.Refill.OtherTokens.title),
                leftButton: .init(
                    content: .icon(.TKUIKit.Icons.Size16.chevronLeft),
                    action: { [weak self] _ in
                        bottomSheetViewController?.dismiss(completion: Self.handOff(from: presentingController) { presentingController in
                            self?.openPayWith(methods: methods, presentingController: presentingController, select: select)
                        })
                    },
                    accessibilityIdentifier: "battery_other_tokens_back"
                )
            )
        ) {
            BatteryOtherTokensView(methods: methods, onSelect: { id in
                bottomSheetViewController?.dismiss { select(id) }
            })
        }
        let sheet = TKBottomSheetViewController(contentViewController: contentViewController)
        bottomSheetViewController = sheet
        sheet.present(fromViewController: presentingController ?? router.rootViewController.topPresentedViewController())
    }

    func openConfirmation(payload: BatteryRechargePayload) {
        rechargePickerRequest.cancel()
        guard let windowScene = router.rootViewController.windowScene else { return }

        let batteryRechargeSignRawBuilder = BatteryRechargeSignRawBuilder(
            wallet: wallet,
            payload: payload,
            batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
            sendService: keeperCoreMainAssembly.servicesAssembly.sendService(),
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )

        SignRawPresenter.presentSignRaw(
            windowScene: windowScene,
            windowLevel: .signRaw,
            wallet: wallet,
            mode: .sendTransaction,
            transferProvider: { try await batteryRechargeSignRawBuilder.getSignRawRequest() },
            resultHandler: BatteryRechargeResultHandler(
                didConfirmRecharge: { [weak self] in
                    self?.analytics.logSuccess(payload.analyticsPurchase)
                    self?.didRechargeSuccess?()
                }
            ),
            sendFrom: .tonconnectRemote,
            initiatedBy: initiatedBy,
            utm: utm,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            didRequireSign: { [weak self] transferData, wallet, coordinator, router throws(WalletTransferSignError) in
                guard let self else {
                    throw .cancelled
                }
                return try await didRequireSign(
                    transferData: transferData,
                    wallet: wallet,
                    coordinator: coordinator,
                    router: router
                )
            }
        )
    }

    func openTokenPicker(token: TonToken, completion: @escaping (TonToken) -> Void) {
        let model = BatteryTokenPickerModel(
            wallet: wallet,
            selectedToken: token,
            balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
            batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService()
        )

        let module = TokenPickerAssembly.module(
            wallet: wallet,
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: module.view,
            ignoreBottomSafeArea: true
        )

        module.output.didSelectToken = { token in
            switch token {
            case .tron: break
            case let .ton(token):
                completion(token)
            }
        }

        module.output.didFinish = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
    }

    @MainActor
    func didRequireSign(
        transferData: TransferData,
        wallet: Wallet,
        coordinator: Coordinator,
        router: ViewControllerRouter
    ) async throws(WalletTransferSignError) -> SignedTransactions {
        let signCoordinator = WalletTransferSignCoordinator(
            router: router,
            wallet: wallet,
            transferData: transferData,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            reason: .topUpBattery
        )

        self.walletTransferSignCoordinator = signCoordinator

        return try await signCoordinator
            .handleSign(parentCoordinator: coordinator)
            .get()
    }

    @MainActor
    func openBatteryRechargeIfNeeded(
        rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider,
        promocodeStore: BatteryPromocodeStore
    ) {
        guard let jettonMasterAddress else { return }
        ToastPresenter.showToast(configuration: .loading)

        Task {
            guard let item = await rechargeMethodsProvider.getRechargeMethod(jettonMasterAddress: jettonMasterAddress) else {
                ToastPresenter.hideAll()
                ToastPresenter.showToast(configuration: .failed)
                return
            }

            ToastPresenter.hideAll()
            openRecharge(item: item, promocodeStore: promocodeStore)
        }
    }
}

private struct BatteryRechargeResultHandler: SignRawControllerResultHandler {
    private let didConfirmRecharge: () -> Void

    init(didConfirmRecharge: @escaping () -> Void) {
        self.didConfirmRecharge = didConfirmRecharge
    }

    func didConfirm(boc _: String) {
        Task { @MainActor in
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: TKLocales.Battery.Recharge.Toast.success))
            didConfirmRecharge()
        }
    }

    func didFail(error _: SomeOf<TransferError, TransactionConfirmationError>) {}

    func didCancel() {}
}

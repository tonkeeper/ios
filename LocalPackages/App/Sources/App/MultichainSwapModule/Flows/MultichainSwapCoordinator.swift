import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class MultichainSwapCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)?
    var didRequestDeeplinkHandling: ((String) -> Void)?
    var didRequestOpenMigration: ((@escaping () -> Void) -> Void)?
    /// Set by hosts that navigate away after a broadcast swap the status tracker cannot follow (e.g. to
    /// history). When unset, such a swap falls back to `didFinish` and just closes the flow, as a
    /// tracked one always does.
    var didSwapSuccessfully: (() -> Void)?

    private let swapWallet: MultichainSwapWallet
    private let nativeSwapContext: NativeSwapContext
    private let assetSource: MultichainSwapAssetSource
    private let raffleStore: RaffleStore?
    private let statusTracker: MultichainSwapStatusTracker?
    private let initiatedBy: InitiatedBy
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let openBattery: (_ onRecharged: @escaping () -> Void) -> Void
    private let openFeeDeposit: (_ assetId: String, _ onDismiss: @escaping () -> Void) -> Void

    private weak var confirmationCoordinator: MultichainSwapConfirmationCoordinator?
    private weak var multichainSwapViewModel: MultichainSwapViewModel?
    private lazy var planProvider = MultichainSwapPlanProvider(
        swapWallet: swapWallet,
        executionService: keeperCoreMainAssembly.multichainSwapExecutionService
    )
    private lazy var swapAnalytics = MultichainSwapAnalytics(
        analyticsProvider: coreAssembly.analyticsProvider,
        wallet: swapWallet.wallet,
        utm: nativeSwapContext.utm
    )

    init(
        swapWallet: MultichainSwapWallet,
        nativeSwapContext: NativeSwapContext,
        assetSource: MultichainSwapAssetSource,
        raffleStore: RaffleStore?,
        statusTracker: MultichainSwapStatusTracker?,
        initiatedBy: InitiatedBy,
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        openBattery: @escaping (_ onRecharged: @escaping () -> Void) -> Void,
        openFeeDeposit: @escaping (_ assetId: String, _ onDismiss: @escaping () -> Void) -> Void
    ) {
        self.swapWallet = swapWallet
        self.nativeSwapContext = nativeSwapContext
        self.assetSource = assetSource
        self.raffleStore = raffleStore
        self.statusTracker = statusTracker
        self.initiatedBy = initiatedBy
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.openBattery = openBattery
        self.openFeeDeposit = openFeeDeposit
        super.init(router: router)
    }

    override func start() {
        openSwap()
    }

    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        confirmationCoordinator?.handleTonkeeperPublishDeeplink(sign: sign) ?? false
    }

    override func didMoveTo(toParent parent: Coordinator?) {
        if parent == nil {
            confirmationCoordinator?.cancelPendingSignerFlow()
        }
    }
}

extension MultichainSwapCoordinator {
    enum MultichainSwapTokenPickSide {
        case send
        case receive
    }
}

private extension MultichainSwapCoordinator {
    func openSwap() {
        Log.multichainSwap.i(
            "coordinator opening swap",
            extraInfo: ["addressChainCount": "\(swapWallet.addresses.count)"]
        )
        router.rootViewController.setNavigationBarHidden(true, animated: false)
        let multichainSwapService = keeperCoreMainAssembly.servicesAssembly.multichainSwapService()
        let defaultAssetsService: MultichainSwapDefaultAssetsService = switch assetSource {
        case let .walletAssets(multichainState, initialSelection):
            DefaultMultichainSwapDefaultAssetsService(
                multichainState: multichainState,
                multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
                multichainSwapService: multichainSwapService,
                assetDetailsService: keeperCoreMainAssembly.servicesAssembly.assetDetailsService(),
                currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
                initialSelection: initialSelection
            )
        case let .legacyPair(sendAssetId, receiveAssetId):
            LegacyPairMultichainSwapDefaultAssetsService(
                wallet: swapWallet.wallet,
                sendAssetId: sendAssetId,
                receiveAssetId: receiveAssetId,
                assetDetailsService: keeperCoreMainAssembly.servicesAssembly.assetDetailsService(),
                convertedBalanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
                currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore
            )
        }
        let viewModel = MultichainSwapViewModel(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            multichainSwapService: multichainSwapService,
            swapWallet: swapWallet,
            defaultAssetsService: defaultAssetsService,
            isAssetSelectionLocked: assetSource.isAssetSelectionLocked,
            displayCurrency: keeperCoreMainAssembly.storesAssembly.currencyStore.state,
            isSwapKitEnabled: keeperCoreMainAssembly.configurationAssembly.configuration.featureEnabled(.swapKitEnabled),
            isExactOutputEnabled: keeperCoreMainAssembly.configurationAssembly.configuration
                .featureEnabled(.swapExactOutputEnabled),
            isSwapV3Enabled: keeperCoreMainAssembly.configurationAssembly.configuration.featureEnabled(.genericPayloadEnabled),
            raffleStore: raffleStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            swapAnalytics: swapAnalytics,
            planProvider: planProvider,
            batteryPromo: makeBatteryPromo(),
            onClose: { [weak self] in
                guard let self else { return }
                didFinish?(self)
            },
            onOpenConfirmation: { [weak self] input, quoteRefreshCycle, phase in
                self?.openConfirmation(
                    confirmationInput: input,
                    quoteRefreshCycle: quoteRefreshCycle,
                    phase: phase
                )
            },
            onInitialSelectionUnavailable: {
                ToastPresenter.showToast(
                    configuration: ToastPresenter.Configuration(
                        title: TKLocales.MultichainSwap.Screen.Swap.Error.assetUnavailable
                    ).withMultichainSwapErrorDuration()
                )
            },
            onQuoteProviderError: { [weak self] message in
                self?.showProviderError(message)
            },
            onQuoteOffline: {
                ToastPresenter.showToast(configuration: .noInternetConnection)
            },
            onTonMaxAmountUnavailable: {
                ToastPresenter.showToast(
                    configuration: ToastPresenter.Configuration(
                        title: TKLocales.MultichainSwap.Screen.Swap.Error.tonMaxAmountUnavailable(
                            NativeSwapConstants.tonFeeReserveWholeUnits
                        )
                    ).withMultichainSwapErrorDuration()
                )
            },
            onOpenRaffle: { [weak self] in
                self?.openMysteryRaffle()
            },
            onOpenPriceImpactInfo: { [weak self] in
                self?.openPriceImpactInfo()
            },
            onRefillBattery: { [weak self] onRecharged in
                // The keyboard would stay over the battery screen.
                self?.router.rootViewController.view.endEditing(true)
                self?.openBattery(onRecharged)
            }
        )
        multichainSwapViewModel = viewModel
        viewModel.onRequestPickSendToken = { [weak self] in
            self?.presentSendTokenV2Picker(side: .send)
        }
        viewModel.onRequestPickReceiveToken = { [weak self] in
            self?.presentSendTokenV2Picker(side: .receive)
        }
        let viewController = MultichainSwapViewController(viewModel: viewModel)
        router.push(viewController: viewController)
        swapAnalytics.logOpen()
    }

    func makeBatteryPromo() -> MultichainSwapBatteryPromo {
        let appSettings = coreAssembly.appSettings
        return MultichainSwapBatteryPromo(
            load: { [keeperCoreMainAssembly, swapWallet] in
                guard !appSettings.isSwapBatteryPromoShown,
                      let coverage = await keeperCoreMainAssembly.emptyBatterySwapCoverage(swapWallet: swapWallet)
                else {
                    return nil
                }
                return coverage.covers
            },
            markShown: {
                appSettings.isSwapBatteryPromoShown = true
            }
        )
    }

    func openMysteryRaffle() {
        MysteryRaffleCoordinator.presentCurrent(
            from: self,
            rootViewController: router.rootViewController,
            source: .swapPromo,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            presentedFromSwapFlow: true,
            swapStatusTracker: statusTracker,
            openDeeplink: { [weak self] in self?.didRequestDeeplinkHandling?($0) },
            openMigration: { [weak self] onFinish in
                self?.didRequestOpenMigration?(onFinish) ?? onFinish()
            }
        )
    }

    /// The keyboard would cover the sheet, so it goes for the sheet's time.
    func openPriceImpactInfo() {
        router.rootViewController.view.endEditing(true)
        let restoreFocus: () -> Void = { [weak self] in
            self?.multichainSwapViewModel?.requestFocusOnAppear()
        }
        let sheet = PopupContentPresenter.present(
            from: router.rootViewController.topPresentedViewController()
        ) { dismisser in
            BulletsInfoPopupView(
                content: BulletsInfoPopupContent(
                    title: TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.title,
                    caption: PriceImpactPresentation.message,
                    captionStyle: .body1,
                    bullets: [],
                    primaryButtonTitle: TKLocales.Actions.gotIt
                ),
                onPrimaryTap: {
                    dismisser.dismiss(completion: restoreFocus)
                }
            )
        }
        sheet.didClose = { _ in
            restoreFocus()
        }
    }

    func presentSendTokenV2Picker(side: MultichainSwapTokenPickSide) {
        guard let swapViewModel = multichainSwapViewModel else {
            Log.multichainSwap.w(
                "token picker requested before swap view model loaded",
                extraInfo: ["side": side.description]
            )
            return
        }

        let swapState: MultichainSwapLoadedState
        switch swapViewModel.state {
        case .shimmer, .error:
            Log.multichainSwap.w(
                "token picker requested before swap view model loaded",
                extraInfo: ["side": side.description]
            )
            return
        case let .loaded(loadedState):
            swapState = loadedState
        }

        let selectedAsset: MultichainAsset?
        switch side {
        case .send:
            selectedAsset = swapState.sendAsset
        case .receive:
            selectedAsset = swapState.receiveAsset
        }

        let modelSide: MultichainSwapTokenPickerSide
        switch side {
        case .send:
            modelSide = .source
        case .receive:
            modelSide = .receive(sourceAssetId: swapState.sendAsset.asset.assetId)
        }

        guard case let .walletAssets(multichainState, _) = assetSource else {
            Log.multichainSwap.w(
                "token picker requested for a fixed pair",
                extraInfo: ["side": side.description]
            )
            return
        }
        let model = MultichainSwapTokenPickerModel(
            side: modelSide,
            multichainState: multichainState,
            selectedAsset: selectedAsset,
            multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore
        )
        Log.multichainSwap.i(
            "token picker opened",
            extraInfo: [
                "side": side.description,
                "sourceAsset": swapState.sendAsset.asset.assetId,
                "destinationAsset": swapState.receiveAsset.asset.assetId,
            ]
        )

        let module = TokenPickerV2Assembly.module(
            title: TKLocales.Multichain.AssetPicker.chooseTitle,
            wallet: swapWallet.wallet,
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        module.output.didSelectAsset = { [weak self] asset in
            self?.selectSwapAsset(asset, for: side)
        }

        module.output.didFinish = { [weak viewController = module.view] in
            viewController?.dismiss(animated: true)
        }

        module.output.didDismiss = { [weak self] in
            self?.multichainSwapViewModel?.requestFocusOnAppear()
        }

        router.rootViewController.topPresentedViewController().present(
            module.view,
            animated: true
        )
    }

    func selectSwapAsset(
        _ asset: MultichainAsset,
        for side: MultichainSwapTokenPickSide
    ) {
        Log.multichainSwap.i(
            "token picker asset selected",
            extraInfo: [
                "side": side.description,
                "asset": asset.asset.assetId,
            ]
        )
        switch side {
        case .send:
            multichainSwapViewModel?.applySendAsset(asset)
        case .receive:
            multichainSwapViewModel?.applyReceiveAsset(asset)
        }
    }

    /// Only a registered wallet's swaps reach the history the tracker reads.
    func sentSwap(
        input: MultichainSwapConfirmationInput,
        result: MultichainSwapExecutionResult
    ) -> MultichainSwapSentSwap? {
        guard swapWallet.walletId != nil, let multichainState = swapWallet.wallet.multichainWalletState else {
            return nil
        }
        let userInput = input.userInput
        return MultichainSwapSentSwap(
            multichainState: multichainState,
            txHash: result.txHash,
            sendAsset: userInput.sendAsset,
            receiveAsset: userInput.receiveAsset,
            sendAmount: input.sourceAmount,
            estimatedReceiveAmount: BigUInt(input.quoteState.route.estimatedDestinationAmount) ?? 0,
            date: Date()
        )
    }

    func openConfirmation(
        confirmationInput: MultichainSwapConfirmationInput,
        quoteRefreshCycle: MultichainSwapQuoteRefreshCycle,
        phase: MultichainSwapConfirmationPhase
    ) {
        Log.multichainSwap.i(
            "coordinator opening confirmation",
            extraInfo: MultichainSwapConfirmationLogInfoMaker(
                priceImpactResolver: MultichainSwapConfirmationPriceImpactResolver()
            ).make(input: confirmationInput, additional: ["phase": "\(phase)"])
        )
        let coordinator = MultichainSwapConfirmationCoordinator(
            swapWallet: swapWallet,
            nativeSwapContext: nativeSwapContext,
            initiatedBy: initiatedBy,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: router,
            confirmationInput: confirmationInput,
            quoteRefreshCycle: quoteRefreshCycle,
            startingPhase: phase,
            planProvider: planProvider,
            openBattery: openBattery,
            openFeeDeposit: openFeeDeposit
        )

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        coordinator.didClose = { [weak self, weak coordinator] refocusesAmount in
            self?.removeChild(coordinator)
            self?.multichainSwapViewModel?.confirmationDidClose(refocusesAmount: refocusesAmount)
        }

        coordinator.didShowPricingDetails = { [weak self] in
            self?.multichainSwapViewModel?.confirmationDidShowPricingDetails()
        }

        coordinator.didChangeSwapInFlight = { [weak self] isInFlight in
            self?.multichainSwapViewModel?.setQuoteHeld(isInFlight)
        }

        coordinator.didRequestFreshQuote = { [weak self] in
            self?.multichainSwapViewModel?.requestFreshQuote()
        }

        coordinator.didRecoverQuote = { [weak self] quoteState in
            self?.multichainSwapViewModel?.adoptConfirmationQuote(quoteState)
        }

        multichainSwapViewModel?.onConfirmationQuoteChange = { [weak coordinator] update in
            coordinator?.updateQuote(update)
        }

        coordinator.didChangeSlippage = { [weak self] bps in
            self?.multichainSwapViewModel?.setSlippageBps(bps)
        }

        coordinator.didChangeFeeMethod = { [weak self] method in
            self?.multichainSwapViewModel?.setFeeMethod(method)
        }

        coordinator.didExecuteSuccessfully = { [weak self, weak coordinator] input, result in
            guard let self else { return }
            removeChild(coordinator)
            if let statusTracker, let sentSwap = sentSwap(input: input, result: result) {
                statusTracker.track(sentSwap)
                didFinish?(self)
                return
            }
            ToastPresenter.showToast(configuration: .confirmed(text: TKLocales.Result.success))
            if let didSwapSuccessfully {
                didSwapSuccessfully()
            } else {
                didFinish?(self)
            }
        }

        coordinator.didFailToSend = { [weak self] failure in
            self?.multichainSwapViewModel?.swapDidFailToSend(failure)
        }

        confirmationCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: nil)
    }
}

private extension MultichainSwapCoordinator {
    /// Every quote repeats the provider's error, so a repeat that updates its toast on screen does not buzz.
    func showProviderError(_ message: String) {
        var configuration = ToastPresenter.Configuration.multichainSwapProviderError(message)
        configuration.playsHaptic = !ToastPresenter.isShowingToast(title: message)
        ToastPresenter.showToast(configuration: configuration)
    }
}

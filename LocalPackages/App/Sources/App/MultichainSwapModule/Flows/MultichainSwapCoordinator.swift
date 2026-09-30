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
    var didRequestFeeDeposit: ((_ assetId: String, _ onDismiss: @escaping () -> Void) -> Void)?
    var didRequestOpenBattery: ((@escaping () -> Void) -> Void)?
    /// Set by hosts that navigate away after a broadcast swap (e.g. to history).
    /// When unset, a successful swap falls back to `didFinish` and just closes the flow.
    var didSwapSuccessfully: (() -> Void)?

    private let wallet: Wallet
    private let multichainState: MultichainWalletState
    private let nativeSwapContext: NativeSwapContext
    private let initialSelection: MultichainSwapInitialAssetSelection?
    private let initiatedBy: InitiatedBy
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    private weak var confirmationCoordinator: MultichainSwapConfirmationCoordinator?
    private weak var multichainSwapViewModel: MultichainSwapViewModel?

    init(
        wallet: Wallet,
        multichainState: MultichainWalletState,
        nativeSwapContext: NativeSwapContext,
        initialSelection: MultichainSwapInitialAssetSelection? = nil,
        initiatedBy: InitiatedBy,
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.wallet = wallet
        self.multichainState = multichainState
        self.nativeSwapContext = nativeSwapContext
        self.initialSelection = initialSelection
        self.initiatedBy = initiatedBy
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
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
            extraInfo: ["addressChainCount": "\(multichainState.addresses.count)"]
        )
        router.rootViewController.setNavigationBarHidden(true, animated: false)
        let multichainSwapService = keeperCoreMainAssembly.servicesAssembly.multichainSwapService()
        let defaultAssetsService = DefaultMultichainSwapDefaultAssetsService(
            multichainState: multichainState,
            multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
            multichainSwapService: multichainSwapService,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            initialSelection: initialSelection
        )
        let viewModel = MultichainSwapViewModel(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            multichainSwapService: multichainSwapService,
            multichainState: multichainState,
            wallet: wallet,
            defaultAssetsService: defaultAssetsService,
            displayCurrency: keeperCoreMainAssembly.storesAssembly.currencyStore.state,
            isSwapKitEnabled: keeperCoreMainAssembly.configurationAssembly.configuration.featureEnabled(.swapKitEnabled),
            raffleStore: keeperCoreMainAssembly.storesAssembly.raffleStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            onClose: { [weak self] in
                guard let self else { return }
                didFinish?(self)
            },
            onContinue: { [weak self] input in
                self?.openConfirmation(confirmationInput: input)
            },
            onInitialSelectionUnavailable: {
                ToastPresenter.showToast(
                    configuration: ToastPresenter.Configuration(
                        title: TKLocales.MultichainSwap.Screen.Swap.Error.assetUnavailable
                    ).withMultichainSwapErrorDuration()
                )
            },
            onQuoteProviderError: { message in
                ToastPresenter.showToast(
                    configuration: .multichainSwapProviderError(message)
                )
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
    }

    func openMysteryRaffle() {
        MysteryRaffleCoordinator.presentCurrent(
            from: self,
            rootViewController: router.rootViewController,
            source: .swapPromo,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            presentedFromSwapFlow: true,
            openDeeplink: { [weak self] in self?.didRequestDeeplinkHandling?($0) },
            openMigration: { [weak self] onFinish in
                self?.didRequestOpenMigration?(onFinish) ?? onFinish()
            }
        )
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

        let model = MultichainSwapTokenPickerModel(
            side: modelSide,
            multichainState: multichainState,
            selectedAsset: selectedAsset,
            multichainService: keeperCoreMainAssembly.servicesAssembly.multichainService(),
            multichainSwapService: keeperCoreMainAssembly.servicesAssembly.multichainSwapService(),
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
            wallet: wallet,
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            waitsForSelectionCompletion: true
        )

        module.output.didSelectAsset = { [weak self, weak output = module.output] asset in
            Task { @MainActor [weak self = self, weak output] in
                guard let self, let output else { return }
                let shouldClose = await self.selectSwapAsset(asset, for: side)
                output.finishAssetSelection(shouldClose: shouldClose)
            }
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
    ) async -> Bool {
        await replaceAssetValidationToast(with: .loading)
        do {
            _ = try await keeperCoreMainAssembly.servicesAssembly.multichainSwapService()
                .getCrossSwapAsset(assetId: asset.asset.assetId)
        } catch {
            let errorToast = ToastPresenter.Configuration(
                title: TKLocales.MultichainSwap.Screen.Confirm.Error.unsupportedAsset
            ).withMultichainSwapErrorDuration()
            await replaceAssetValidationToast(with: errorToast)
            Log.multichainSwap.w(
                "token picker selected unsupported asset",
                error: error,
                extraInfo: [
                    "side": side.description,
                    "asset": asset.asset.assetId,
                ]
            )
            return false
        }

        await hideAssetValidationToast()
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
        return true
    }

    func replaceAssetValidationToast(
        with configuration: ToastPresenter.Configuration
    ) async {
        await withCheckedContinuation { continuation in
            ToastPresenter.hideToast {
                ToastPresenter.showToast(configuration: configuration)
                continuation.resume()
            }
        }
    }

    func hideAssetValidationToast() async {
        await withCheckedContinuation { continuation in
            ToastPresenter.hideToast {
                continuation.resume()
            }
        }
    }

    func openConfirmation(confirmationInput: MultichainSwapConfirmationInput) {
        Log.multichainSwap.i(
            "coordinator opening confirmation",
            extraInfo: MultichainSwapConfirmationLogInfoMaker(
                priceImpactResolver: MultichainSwapConfirmationPriceImpactResolver()
            ).make(input: confirmationInput)
        )
        let coordinator = MultichainSwapConfirmationCoordinator(
            wallet: wallet,
            nativeSwapContext: nativeSwapContext,
            initiatedBy: initiatedBy,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: router,
            confirmationInput: confirmationInput,
            rateText: confirmationInput.userInput.rateText
        )

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        // Left unset when this flow's own host has no battery screen, so the confirmation opens one
        // itself instead of forwarding into a nil closure that drops the tap.
        if let didRequestOpenBattery {
            coordinator.didRequestOpenBattery = didRequestOpenBattery
        }

        coordinator.didClose = { [weak self, weak coordinator] in
            self?.didFinish?(self)
            self?.removeChild(coordinator)
        }

        coordinator.didExecuteSuccessfully = { [weak self, weak coordinator] in
            guard let self else { return }
            removeChild(coordinator)
            if let didSwapSuccessfully {
                didSwapSuccessfully()
            } else {
                didFinish?(self)
            }
        }

        coordinator.didTapEdit = { [weak self, weak coordinator] _ in
            self?.removeChild(coordinator)
        }

        coordinator.didTapBack = { [weak self, weak coordinator] in
            self?.removeChild(coordinator)
        }

        if let didRequestFeeDeposit {
            coordinator.didRequestFeeDeposit = didRequestFeeDeposit
        }

        coordinator.didRequestOpenBuySell = { [weak self, weak coordinator] isInternalPurchasing in
            self?.didRequestOpenBuySell?(isInternalPurchasing)
            self?.didFinish?(self)
            self?.removeChild(coordinator)
        }

        confirmationCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: nil)
    }
}

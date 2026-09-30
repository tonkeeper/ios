import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class MultichainSwapConfirmationCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didClose: (() -> Void)?
    var didExecuteSuccessfully: (() -> Void)?
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)?
    var didRequestFeeDeposit: ((_ assetId: String, _ onDismiss: @escaping () -> Void) -> Void)?
    var didRequestOpenBattery: ((@escaping () -> Void) -> Void)?
    var didTapEdit: ((Bool?) -> Void)?
    var didTapBack: (() -> Void)?

    private let wallet: Wallet
    private let confirmationInput: MultichainSwapConfirmationInput
    private let initiatedBy: InitiatedBy
    private let utm: UtmParameters
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let nativeFeeShortagePopupPresenter: MultichainNativeFeeShortagePopupPresenter
    private var confirmationViewModel: MultichainSwapConfirmationViewModel?
    private var priceImpactCoordinator: PriceImpactCoordinator?
    private lazy var feePickerCoordinator = NetworkFeePickerCoordinator(router: router)

    init(
        wallet: Wallet,
        nativeSwapContext: NativeSwapContext,
        initiatedBy: InitiatedBy,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter,
        confirmationInput: MultichainSwapConfirmationInput,
        rateText _: String
    ) {
        self.wallet = wallet
        self.confirmationInput = confirmationInput
        self.initiatedBy = initiatedBy
        self.utm = nativeSwapContext.utm
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        nativeFeeShortagePopupPresenter = MultichainNativeFeeShortagePopupPresenter(
            wallet: wallet,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        super.init(router: router)
    }

    override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
        openConfirmation()
    }

    func handleTonkeeperPublishDeeplink(sign _: Data) -> Bool {
        false
    }

    func cancelPendingSignerFlow() {}
}

private extension MultichainSwapConfirmationCoordinator {
    func openConfirmation() {
        let viewModel = MultichainSwapConfirmationViewModel(
            wallet: wallet,
            confirmationInput: confirmationInput,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            executionService: keeperCoreMainAssembly.multichainSwapExecutionService,
            multichainSwapService: keeperCoreMainAssembly.servicesAssembly.multichainSwapService(),
            isSwapKitEnabled: keeperCoreMainAssembly.configurationAssembly.configuration.featureEnabled(.swapKitEnabled),
            onBack: { [weak self] in
                guard let self else { return }
                didTapBack?()
                router.rootViewController.popViewController(animated: true)
            },
            onClose: { [weak self] in
                self?.didClose?()
            },
            onSwipeConfirm: { [weak self] in
                self?.confirmSwap()
            },
            onExecutionCompleted: { [weak self] input, feeMethod in
                ToastPresenter.showToast(
                    configuration: .confirmed(text: TKLocales.Result.success)
                )
                self?.logTransactionSent(input: input, feeMethod: feeMethod)
                self?.didExecuteSuccessfully?()
            },
            onExecutionFailed: { message in
                ToastPresenter.showToast(
                    configuration: .warning(text: message.isEmpty ? TKLocales.Toast.failed : message)
                        .withMultichainSwapErrorDuration()
                )
            },
            onQuoteProviderError: { message in
                ToastPresenter.showToast(
                    configuration: .multichainSwapProviderError(message)
                )
            },
            onInsufficientNativeFee: { [weak self] shortage in
                self?.handleNativeFeeShortage(shortage)
            },
            onFeeCalculationStarted: { [weak self] reason in
                switch reason {
                case .initial, .slippageChanged, .feeDeposit:
                    self?.nativeFeeShortagePopupPresenter.startNewFeeCalculation()
                case .timer, .executionFailed:
                    break
                }
            },
            onOpenFeePicker: { [weak self] presentation in
                self?.feePickerCoordinator.start(presentation: presentation)
            },
            onRefillBattery: { [weak self] onRecharged in
                self?.openBatteryRefill(onRecharged: onRecharged)
            },
            onBatteryFeeShortage: { [weak self] shortage in
                self?.handleBatteryFeeShortage(shortage)
            },
            onDepositNativeFee: { [weak self] asset in
                self?.depositFeeAsset(asset)
            }
        )
        confirmationViewModel = viewModel
        viewModel.onRequestSlippageSelection = { [weak self] sourceView in
            self?.openSlippageMenu(sourceView: sourceView)
        }
        let viewController = MultichainSwapConfirmationViewController(viewModel: viewModel)

        router.push(viewController: viewController)
    }

    func confirmSwap() {
        guard let confirmationViewModel else {
            return Log.multichainSwap.w(
                "confirmation requested without view model",
                extraInfo: confirmationLogInfo()
            )
        }
        switch confirmationViewModel.priceImpactSeverity {
        case .none:
            executeSwap()
        case .warning:
            openPriceImpact(style: .warning)
        case .danger:
            openPriceImpact(style: .danger)
        }
    }

    func executeSwap() {
        Log.multichainSwap.i(
            "coordinator executing swap",
            extraInfo: confirmationLogInfo()
        )
        confirmationViewModel?.execute(passcodeProvider: { [weak self, keeperCoreMainAssembly] in
            guard let self else {
                return nil
            }
            return await PasscodeInputCoordinator.getPasscode(
                parentCoordinator: self,
                parentRouter: router,
                mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess,
                securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
            )
        })
    }

    func openPriceImpact(style: PriceImpactPresentationStyle) {
        Log.multichainSwap.w(
            "price impact warning opened",
            extraInfo: confirmationLogInfo()
        )
        let presentation = PriceImpactPresentation(
            style: style,
            title: TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.title,
            subtitle: TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.subtitle,
            description: TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.description,
            confirmButtonTitle: TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.confirmButton,
            backButtonTitle: TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.backButton,
            didTapClose: { [weak self] in
                self?.confirmationViewModel?.resetConfirmSlider()
            },
            didTapConfirm: { [weak self] in
                Log.multichainSwap.i(
                    "price impact warning confirmed",
                    extraInfo: self?.confirmationLogInfo() ?? [:]
                )
                self?.executeSwap()
            },
            didTapBack: { [weak self] in
                self?.confirmationViewModel?.resetConfirmSlider()
            }
        )

        let coordinator = PriceImpactCoordinator(router: router)
        priceImpactCoordinator = coordinator
        coordinator.start(presentation: presentation)
    }

    func openSlippageMenu(sourceView: UIView) {
        guard let confirmationViewModel,
              !confirmationViewModel.slippageOptions.isEmpty
        else {
            Log.multichainSwap.w(
                "slippage menu requested without available options",
                extraInfo: confirmationLogInfo()
            )
            return
        }
        guard sourceView.window != nil else {
            Log.multichainSwap.w(
                "slippage menu requested without source view window",
                extraInfo: confirmationLogInfo()
            )
            return
        }

        let options = confirmationViewModel.slippageOptions
        let selectedIndex = options.firstIndex(of: confirmationViewModel.selectedSlippageBps)
        let items = options.map { option in
            TKPopupMenuItem(
                title: confirmationViewModel.slippageTitle(bps: option),
                selectionHandler: { [weak confirmationViewModel] in
                    confirmationViewModel?.selectSlippageBps(option)
                }
            )
        }
        TKPopupMenuController.show(
            sourceView: sourceView,
            position: .bottomRight(inset: 0),
            minimumWidth: 160,
            items: items,
            selectedIndex: selectedIndex
        )
    }

    func handleNativeFeeShortage(_ shortage: MultichainNativeFeeShortage) {
        nativeFeeShortagePopupPresenter.presentIfNeeded(
            shortage: shortage,
            from: router.rootViewController.topPresentedViewController(),
            onDeposit: { [weak self] asset in
                self?.depositFeeAsset(asset)
            }
        )
    }

    func handleBatteryFeeShortage(_ shortage: MultichainNativeFeeShortage) {
        nativeFeeShortagePopupPresenter.presentBatteryOptionIfNeeded(
            shortage: shortage,
            from: router.rootViewController.topPresentedViewController(),
            onRecharge: { [weak self] in
                self?.openBatteryRefill { [weak self] in
                    self?.confirmationViewModel?.refreshFeeCalculationAfterDeposit()
                }
            },
            onDeposit: { [weak self] asset in
                self?.depositFeeAsset(asset)
            }
        )
    }

    /// A host with a battery flow of its own wires `didRequestOpenBattery`; the raffle hands the
    /// swap off without one, and a fee row that cannot be paid still has to reach a recharge. So the
    /// flow opens it on its own router instead of dropping the tap, the same way an unwired deposit
    /// falls back to the receive screen.
    func openBatteryRefill(onRecharged: @escaping () -> Void) {
        if let didRequestOpenBattery {
            didRequestOpenBattery(onRecharged)
            return
        }

        let navigationController = TKNavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let coordinator = BatteryRefillCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            wallet: wallet,
            jettonMasterAddress: nil,
            initiatedBy: initiatedBy,
            utm: utm,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        coordinator.didRechargeSuccess = { [weak self, weak navigationController, weak coordinator] in
            navigationController?.dismiss(animated: true) {
                self?.removeChild(coordinator)
                onRecharged()
            }
        }
        coordinator.didFinish = { [weak self, weak navigationController] coordinator in
            navigationController?.dismiss(animated: true)
            self?.removeChild(coordinator)
        }

        addChild(coordinator)
        coordinator.start(deeplink: nil)
        router.presentOverTopPresented(
            navigationController,
            completion: {
                coordinator.didAppear()
            },
            onDismiss: { [weak self, weak coordinator] in
                self?.removeChild(coordinator)
            }
        )
    }

    func depositFeeAsset(_ asset: MultichainAssetDetails) {
        guard let didRequestFeeDeposit else {
            openReceive(for: asset)
            return
        }
        didRequestFeeDeposit(asset.assetId) { [weak self] in
            self?.confirmationViewModel?.refreshFeeCalculationAfterDeposit()
        }
    }

    func openReceive(for asset: MultichainAssetDetails) {
        guard case let .multichain(multichainState) = wallet.multichain,
              let chain = asset.chain,
              let address = multichainState.walletAddress(
                  for: chain,
                  preferredType: wallet.preferredMultichainAddressType(for: chain)
              )
        else {
            return Log.multichainSwap.w(
                "deposit skipped - no receive address for fee asset",
                extraInfo: ["assetId": asset.assetId]
            )
        }
        let coordinator = ReceiveModule(
            dependencies: .init(
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        ).createReceiveCoordinator(
            router: router,
            wallet: wallet,
            address: ReceiveAddressPreview(address: address)
        )
        coordinator.didClose = { [weak self, weak coordinator] in
            guard let self else { return }
            removeChild(coordinator)
            confirmationViewModel?.refreshFeeCalculationAfterDeposit()
        }
        addChild(coordinator)
        coordinator.start()
    }

    func logTransactionSent(
        input: MultichainSwapConfirmationInput,
        feeMethod: MultichainSwapFeeMethod
    ) {
        let userInput = input.userInput
        guard let event = TransactionSent(
            wallet: wallet,
            swapFromAsset: userInput.sendAsset.asset.assetId,
            fromAssetDecimals: userInput.sendAsset.asset.decimals,
            toAsset: userInput.receiveAsset.asset.assetId,
            amount: userInput.sourceAmount,
            feeAsset: FeeAsset(multichainSwapFeeMethod: feeMethod),
            origin: TransactionOrigin(initiatedBy: initiatedBy, utm: utm),
            isMax: userInput.isMax
        ) else {
            return
        }
        coreAssembly.analyticsProvider.log(event, utm: utm)
    }

    func confirmationLogInfo(additional: [String: String] = [:]) -> [String: String] {
        let input = confirmationViewModel?.currentConfirmationInput ?? confirmationInput
        return MultichainSwapConfirmationLogInfoMaker(
            priceImpactResolver: MultichainSwapConfirmationPriceImpactResolver()
        ).make(input: input, additional: additional)
    }
}

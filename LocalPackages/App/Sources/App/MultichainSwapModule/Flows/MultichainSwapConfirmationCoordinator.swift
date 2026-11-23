import AppUI
import Combine
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class MultichainSwapConfirmationCoordinator: RouterCoordinator<NavigationControllerRouter> {
    /// The confirmation went away with no swap made: its sheet closed, or a swap started by the Swap
    /// button ended without one. The amount takes the keyboard back unless a popup the swap left covers it.
    var didClose: ((_ refocusesAmount: Bool) -> Void)?
    /// A swap started by the Swap button could not go straight to the passcode, so the pricing
    /// details opened to show why.
    var didShowPricingDetails: (() -> Void)?
    /// A swap is on its way, so the swap screen's quote has to hold still.
    var didChangeSwapInFlight: ((Bool) -> Void)?
    var didRequestFreshQuote: (() -> Void)?
    var didRecoverQuote: ((MultichainSwapConfirmationQuoteState) -> Void)?
    var didChangeSlippage: ((Int) -> Void)?
    var didChangeFeeMethod: ((MultichainSwapFeeMethod?) -> Void)?
    var didExecuteSuccessfully: ((MultichainSwapConfirmationInput, MultichainSwapExecutionResult) -> Void)?
    var didFailToSend: ((MultichainSwapSendFailure) -> Void)?

    private let swapWallet: MultichainSwapWallet
    private let confirmationInput: MultichainSwapConfirmationInput
    private let quoteRefreshCycle: MultichainSwapQuoteRefreshCycle
    private let startingPhase: MultichainSwapConfirmationPhase
    private let initiatedBy: InitiatedBy
    private let utm: UtmParameters
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let openBattery: (_ onRecharged: @escaping () -> Void) -> Void
    private let openFeeDeposit: (_ assetId: String, _ onDismiss: @escaping () -> Void) -> Void
    private let planProvider: MultichainSwapPlanProvider
    private let nativeFeeShortagePopupPresenter: MultichainNativeFeeShortagePopupPresenter
    private var confirmationViewModel: MultichainSwapConfirmationViewModel?
    private weak var bottomSheetViewController: TKBottomSheetViewController?
    /// The fee picker that took the pricing details' place is up: the confirmation is not one without a sheet.
    private var isFeePickerReplacingSheet = false
    /// The sheet has slid out for the fee picker, but its dismissal has not completed yet. Weak, so a sheet
    /// taken from outside before then does not hold the guards on.
    private weak var sheetLeavingForFeePicker: TKBottomSheetViewController?
    /// A top-up the picker led to took the screen, so the amount does not take the keyboard back.
    private var feePickerStartedTopUp = false
    private var sheetHeightUpdates: AnyCancellable?
    private var sheetModalityUpdates: AnyCancellable?
    private var priceImpactCoordinator: PriceImpactCoordinator?
    private lazy var feePickerCoordinator = NetworkFeePickerCoordinator(router: router)
    /// Hosted by the swap screen, as a one-tap swap has no sheet: the review is asked over whatever
    /// the screen presents on top, the pricing details when they are up.
    private lazy var consentPresenter = OperationConsentPresenter(host: { [weak self] in self?.router.rootViewController })

    init(
        swapWallet: MultichainSwapWallet,
        nativeSwapContext: NativeSwapContext,
        initiatedBy: InitiatedBy,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter,
        confirmationInput: MultichainSwapConfirmationInput,
        quoteRefreshCycle: MultichainSwapQuoteRefreshCycle,
        startingPhase: MultichainSwapConfirmationPhase,
        planProvider: MultichainSwapPlanProvider,
        openBattery: @escaping (_ onRecharged: @escaping () -> Void) -> Void,
        openFeeDeposit: @escaping (_ assetId: String, _ onDismiss: @escaping () -> Void) -> Void
    ) {
        self.swapWallet = swapWallet
        self.planProvider = planProvider
        self.confirmationInput = confirmationInput
        self.quoteRefreshCycle = quoteRefreshCycle
        self.startingPhase = startingPhase
        self.initiatedBy = initiatedBy
        self.utm = nativeSwapContext.utm
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.openBattery = openBattery
        self.openFeeDeposit = openFeeDeposit
        nativeFeeShortagePopupPresenter = MultichainNativeFeeShortagePopupPresenter(
            wallet: swapWallet.wallet,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        super.init(router: router)
    }

    override func start(deeplink: (any CoordinatorDeeplink)? = nil) {
        let viewModel = makeViewModel()
        confirmationViewModel = viewModel
        router.rootViewController.view.endEditing(true)
        guard startingPhase == .swapping else {
            presentSheet()
            viewModel.prepareExecutionPlan()
            return
        }
        startSwap()
    }

    func updateQuote(_ update: MultichainSwapConfirmationQuoteUpdate) {
        confirmationViewModel?.updateQuote(update)
    }

    func handleTonkeeperPublishDeeplink(sign _: Data) -> Bool {
        false
    }

    func cancelPendingSignerFlow() {
        consentPresenter.hostDidLeave()
    }

    /// However the confirmation ended, a review still waiting for an answer is refused and its
    /// sheet closed.
    override func didMoveTo(toParent parent: Coordinator?) {
        if parent == nil {
            consentPresenter.hostDidLeave()
        }
    }
}

private extension MultichainSwapConfirmationCoordinator {
    func makeViewModel() -> MultichainSwapConfirmationViewModel {
        let assetBalanceProvider = keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider
        let wallet = swapWallet.wallet
        let viewModel = MultichainSwapConfirmationViewModel(
            swapWallet: swapWallet,
            confirmationInput: confirmationInput,
            quoteRefreshCycle: quoteRefreshCycle,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter,
            executionService: keeperCoreMainAssembly.multichainSwapExecutionService,
            planProvider: planProvider,
            multichainSwapService: keeperCoreMainAssembly.servicesAssembly.multichainSwapService(),
            isSwapKitEnabled: keeperCoreMainAssembly.configurationAssembly.configuration.featureEnabled(.swapKitEnabled),
            displayCurrency: keeperCoreMainAssembly.storesAssembly.currencyStore.state,
            walletAsset: { assetId in
                assetBalanceProvider.cachedAsset(for: assetId, wallet: wallet)
            },
            swapAnalytics: MultichainSwapAnalytics(
                analyticsProvider: coreAssembly.analyticsProvider,
                wallet: wallet,
                utm: utm
            ),
            onConfirm: { [weak self] in
                self?.confirmSwap()
            },
            onPriceChanged: { [weak self] message in
                self?.openPriceChange(message: message)
            },
            onConfirmUnavailable: { [weak self] in
                self?.showPricingDetails()
            },
            onSwapInFlightChange: { [weak self] isInFlight in
                self?.didChangeSwapInFlight?(isInFlight)
            },
            onRefreshQuote: { [weak self] in
                self?.didRequestFreshQuote?()
            },
            onQuoteRecovered: { [weak self] quoteState in
                self?.didRecoverQuote?(quoteState)
            },
            onSlippageChange: { [weak self] bps in
                self?.didChangeSlippage?(bps)
            },
            onFeeMethodChange: { [weak self] method in
                self?.didChangeFeeMethod?(method)
            },
            onExecutionCompleted: { [weak self] input, feeMethod, result in
                self?.logTransactionSent(input: input, feeMethod: feeMethod)
                self?.finishSwap(input: input, result: result)
            },
            onExecutionFailed: { [weak self] message, canRetry in
                guard let self else { return }
                let failure: MultichainSwapSendFailure = canRetry ? .retryable(message) : .outcomeUnknown
                // Without the sheet the swap screen shows the failure in place of its Swap button.
                guard bottomSheetViewController != nil else {
                    didFailToSend?(failure)
                    endSwapWithoutSheet()
                    return
                }
                // The sheet holds its own Swap back, and the swap screen has to go on doing so once the
                // sheet is closed.
                guard canRetry else {
                    didFailToSend?(failure)
                    return
                }
                ToastPresenter.showToast(
                    configuration: .warning(text: message.isEmpty ? TKLocales.Toast.failed : message, feedback: .failure)
                        .withMultichainSwapErrorDuration()
                )
            },
            onExecutionCanceled: { [weak self] in
                self?.endSwapWithoutSheet()
            },
            onPreparationFailed: { [weak self] message in
                ToastPresenter.showToast(
                    configuration: .warning(text: message.isEmpty ? TKLocales.Toast.failed : message, feedback: .failure)
                        .withMultichainSwapErrorDuration()
                )
                self?.didRequestFreshQuote?()
                self?.endSwapWithoutSheet()
                self?.closeForFreshQuote()
            },
            onInsufficientNativeFee: { [weak self] shortage in
                self?.showFeeShortage { self?.handleNativeFeeShortage(shortage) }
            },
            onOpenFeePicker: { [weak self] presentation in
                self?.openFeePicker(presentation)
            },
            onRefillBattery: { [weak self] _ in
                // The picker may have closed the pricing details, so the swap screen reads the fee again.
                guard let self else { return }
                feePickerStartedTopUp = isFeePickerReplacingSheet
                openBattery(feeTopUpCompletion())
            },
            onBatteryFeeShortage: { [weak self] shortage in
                self?.showFeeShortage { self?.handleBatteryFeeShortage(shortage) }
            },
            onDepositNativeFee: { [weak self] asset in
                guard let self else { return }
                feePickerStartedTopUp = isFeePickerReplacingSheet
                depositFeeAsset(asset)
            }
        )
        viewModel.onRequestSlippageSelection = { [weak self] sourceView in
            self?.openSlippageMenu(sourceView: sourceView)
        }
        return viewModel
    }

    func presentSheet() {
        guard let viewModel = confirmationViewModel else {
            return
        }
        let contentViewController = TKBottomSheetHostingController(
            content: MultichainSwapConfirmationViewContainer(viewModel: viewModel),
            headerConfiguration: TKBottomSheetHeaderConfiguration(
                title: .title(title: TKLocales.MultichainSwap.Screen.Confirm.title)
            )
        )
        sheetHeightUpdates = viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak contentViewController] in
                contentViewController?.didUpdateHeight?()
            }
        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: contentViewController,
            ignoreBottomSafeArea: true
        )
        // Closed while the swap is sent, the sheet would take its outcome along: the swap screen would
        // neither leave for the history nor show the failure, and would offer the same swap again.
        sheetModalityUpdates = viewModel.$executionState
            .map { !$0.isConfirmEnabled }
            .removeDuplicates()
            .sink { [weak bottomSheetViewController] isSending in
                bottomSheetViewController?.isModalInPresentation = isSending
            }
        bottomSheetViewController.didClose = { [weak self] _ in
            self?.didClose?(true)
        }
        self.bottomSheetViewController = bottomSheetViewController
        bottomSheetViewController.present(
            fromViewController: router.rootViewController.topPresentedViewController()
        )
    }

    /// The picker takes the pricing details' place over the swap screen instead of going over them. The
    /// confirmation stays until the picker is gone, as the pick and the top-ups it starts go through it.
    /// A sheet held up while the swap is sent stays, and the picker goes over it.
    func openFeePicker(_ presentation: NetworkFeePickerPresentation) {
        guard sheetLeavingForFeePicker == nil else {
            return
        }
        guard let sheet = bottomSheetViewController, !sheet.isDismissing, !sheet.isModalInPresentation else {
            feePickerCoordinator.start(presentation: presentation)
            return
        }
        // The sheet is let go only once it has left: until then its `isDismissing` keeps a Swap tapped on it
        // from going on. A top-up started from the picker then refreshes the swap screen.
        sheetLeavingForFeePicker = sheet
        sheet.dismiss { [weak self] in
            guard let self else { return }
            sheetLeavingForFeePicker = nil
            bottomSheetViewController = nil
            isFeePickerReplacingSheet = true
            feePickerStartedTopUp = false
            feePickerCoordinator.start(presentation: presentation, didFinish: { [weak self] in
                guard let self else { return }
                isFeePickerReplacingSheet = false
                didClose?(!feePickerStartedTopUp)
            })
        }
    }

    private var isSheetLeaving: Bool {
        bottomSheetViewController?.isDismissing == true || sheetLeavingForFeePicker != nil
    }

    /// A swap started by the Swap button has no sheet, and one it cannot confirm opens the pricing details.
    func showPricingDetails() {
        guard bottomSheetViewController == nil, !isFeePickerReplacingSheet else {
            return
        }
        presentSheet()
        didShowPricingDetails?()
    }

    /// The ways to pay a fee nothing pays open over the pricing details when they are open. A swap tapped on the
    /// swap screen did not open them, so its popup goes over that screen alone. A sheet on its way out takes no
    /// popup: the popup would leave with it.
    func showFeeShortage(_ present: () -> Void) {
        if !isSheetLeaving {
            present()
        }
    }

    /// A swap started by the Swap button that stops short of sending hands the swap screen back.
    func endSwapWithoutSheet() {
        guard bottomSheetViewController == nil, !isFeePickerReplacingSheet else {
            return
        }
        didClose?(true)
    }

    /// A swap started by the Swap button that left its fee popup over the swap screen ends at once: the popup's
    /// ways to pay go through the swap screen's own top-ups, and the keyboard stays down under it.
    func endSwapUnderPopup() {
        guard bottomSheetViewController == nil, !isFeePickerReplacingSheet else {
            return
        }
        didClose?(false)
    }

    /// The failure arrives from a refresh rather than a tap, so the sheet only leaves while it is on
    /// top: a top-up flow it opened is the user's own errand, and the sheet stays for when they are back.
    func closeForFreshQuote() {
        guard let bottomSheetViewController, sheetLeavingForFeePicker == nil,
              bottomSheetViewController.navigationController?.presentedViewController == nil
        else {
            return
        }
        bottomSheetViewController.dismiss { [weak self] in
            self?.didClose?(true)
        }
    }

    /// The host takes the swap screen down next, and a screen that still presents the sheet would drop
    /// only the sheet.
    func finishSwap(input: MultichainSwapConfirmationInput, result: MultichainSwapExecutionResult) {
        guard router.rootViewController.presentedViewController != nil else {
            didExecuteSuccessfully?(input, result)
            return
        }
        router.rootViewController.dismiss(animated: false) { [weak self] in
            self?.didExecuteSuccessfully?(input, result)
        }
    }

    func confirmSwap() {
        guard let confirmationViewModel else {
            return Log.multichainSwap.w(
                "confirmation requested without view model",
                extraInfo: confirmationLogInfo()
            )
        }
        guard !confirmationViewModel.isPriceImpactAccepted,
              let style = confirmationViewModel.priceImpactSeverity.warningStyle
        else {
            return executeSwap()
        }
        openPriceImpact(style: style) { [weak self] in
            self?.executeSwap()
        }
    }

    /// The quote alone sets the price impact, so a swap from the swap screen asks about it at once and
    /// prepares its plan once the user agrees. The swap is pending from the tap, which holds the swap
    /// screen's quote: the plan is prepared for the price the warning was answered for.
    func startSwap() {
        guard let confirmationViewModel else {
            return
        }
        confirmationViewModel.confirmWhenReady()
        guard let style = confirmationViewModel.priceImpactSeverity.warningStyle else {
            return confirmationViewModel.prepareExecutionPlan()
        }
        openPriceImpact(style: style) { [weak self] in
            self?.confirmationViewModel?.acceptPriceImpact()
            self?.confirmationViewModel?.prepareExecutionPlan()
        }
    }

    func executeSwap() {
        Log.multichainSwap.i(
            "coordinator executing swap",
            extraInfo: confirmationLogInfo()
        )
        confirmationViewModel?.execute(signer: swapSigner(), consent: consentPresenter.consent())
    }

    /// A Ledger signs the swap on the device, over the confirmation; any other wallet unlocks its mnemonic.
    func swapSigner() -> MultichainTransferSigner {
        let device = LedgerDeviceSigner.signer(
            for: swapWallet.wallet,
            unavailableTitle: TKLocales.LedgerSteps.dappsUnavailable,
            coreAssembly: coreAssembly,
            presenter: { [weak self] in self?.router.rootViewController }
        )
        if let device {
            return .device(device)
        }
        return .mnemonic(passcodeProvider: { [weak self, keeperCoreMainAssembly] in
            // The passcode screen would leave with a closing sheet and never answer, so the swap stops.
            guard let self, !isSheetLeaving else {
                return nil
            }
            return await PasscodeInputCoordinator.getPasscode(
                parentCoordinator: self,
                parentRouter: router,
                mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess,
                securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
                reason: .confirmSwap
            )
        })
    }

    func openPriceImpact(style: PriceImpactPresentationStyle, onConfirm: @escaping () -> Void) {
        Log.multichainSwap.w(
            "price impact warning opened",
            extraInfo: confirmationLogInfo()
        )
        openWarning(
            style: style,
            title: TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.title,
            message: PriceImpactPresentation.message,
            confirmButtonTitle: TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.confirmButton,
            onConfirm: { [weak self] in
                Log.multichainSwap.i(
                    "price impact warning confirmed",
                    extraInfo: self?.confirmationLogInfo() ?? [:]
                )
                onConfirm()
            }
        )
    }

    /// The swap is pinned to the recovered route, so agreeing to its price goes on as a confirmation does,
    /// through that route's own price impact warning.
    func openPriceChange(message: String) {
        openWarning(
            style: .danger,
            title: TKLocales.MultichainSwap.Screen.Confirm.PriceChanged.title,
            message: message,
            confirmButtonTitle: TKLocales.MultichainSwap.Screen.Confirm.PriceChanged.confirmButton,
            onConfirm: { [weak self] in
                Log.multichainSwap.i(
                    "price change warning confirmed",
                    extraInfo: self?.confirmationLogInfo() ?? [:]
                )
                self?.confirmSwap()
            }
        )
    }

    func openWarning(
        style: PriceImpactPresentationStyle,
        title: String,
        message: String,
        confirmButtonTitle: String,
        onConfirm: @escaping () -> Void
    ) {
        let presentation = PriceImpactPresentation(
            style: style,
            title: title,
            message: message,
            confirmButtonTitle: confirmButtonTitle,
            backButtonTitle: TKLocales.NativeSwap.Screen.Confirm.PriceImpactAlert.backButton,
            didTapClose: { [weak self] in
                self?.backOutOfWarning()
            },
            didTapConfirm: onConfirm,
            didTapBack: { [weak self] in
                self?.backOutOfWarning()
            }
        )

        let coordinator = PriceImpactCoordinator(router: router)
        priceImpactCoordinator = coordinator
        coordinator.start(presentation: presentation)
    }

    func backOutOfWarning() {
        confirmationViewModel?.cancelConfirm()
        endSwapWithoutSheet()
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
            position: .topRight,
            minimumWidth: 160,
            items: items,
            selectedIndex: selectedIndex
        )
    }

    func handleNativeFeeShortage(_ shortage: MultichainNativeFeeShortage) {
        nativeFeeShortagePopupPresenter.present(
            shortage: shortage,
            from: router.rootViewController.topPresentedViewController(),
            onDeposit: feeDeposit()
        )
        endSwapUnderPopup()
    }

    func handleBatteryFeeShortage(_ shortage: MultichainNativeFeeShortage) {
        let afterRecharge = feeTopUpCompletion()
        nativeFeeShortagePopupPresenter.presentBatteryOption(
            shortage: shortage,
            from: router.rootViewController.topPresentedViewController(),
            onRecharge: { [openBattery] in
                openBattery(afterRecharge)
            },
            onDeposit: feeDeposit()
        )
        endSwapUnderPopup()
    }

    func depositFeeAsset(_ asset: MultichainAssetDetails) {
        feeDeposit()(asset)
    }

    /// The deposit goes through the swap screen's own top-up rather than through this coordinator, so a popup left
    /// over the swap screen still offers it once the swap has ended.
    func feeDeposit() -> (MultichainAssetDetails) -> Void {
        let completion = feeTopUpCompletion()
        return { [openFeeDeposit] asset in
            openFeeDeposit(asset.assetId, completion)
        }
    }

    /// The fee is estimated again once a top-up closes: by the pricing details when they are open, else by a
    /// fresh quote on the swap screen, as the swap that offered the top-up ended without them.
    func feeTopUpCompletion() -> () -> Void {
        guard bottomSheetViewController != nil else {
            return { [didRequestFreshQuote] in
                didRequestFreshQuote?()
            }
        }
        return { [weak self] in
            self?.confirmationViewModel?.refreshFeeCalculationAfterDeposit()
        }
    }

    func logTransactionSent(
        input: MultichainSwapConfirmationInput,
        feeMethod: MultichainSwapFeeMethod
    ) {
        let userInput = input.userInput
        guard let event = TransactionSent(
            wallet: swapWallet.wallet,
            swapFromAsset: userInput.sendAsset.asset.assetId,
            fromAssetDecimals: userInput.sendAsset.asset.decimals,
            toAsset: userInput.receiveAsset.asset.assetId,
            amount: input.sourceAmount,
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

private extension MultichainSwapPriceImpactSeverity {
    var warningStyle: PriceImpactPresentationStyle? {
        switch self {
        case .none:
            nil
        case .warning:
            .warning
        case .danger:
            .danger
        }
    }
}

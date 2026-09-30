import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLogging
import TKUIKit

@MainActor
final class MultichainSwapViewModel: ObservableObject {
    let amountFormatter: AmountFormatter
    let quoteRefreshDuration: TimeInterval = 30

    private let multichainState: MultichainWalletState
    private let wallet: Wallet
    private let defaultAssetsService: MultichainSwapDefaultAssetsService
    private var raffleObserver: MysteryRafflePresentationObserver?
    private var shownRaffleBannerIDs = Set<String>()
    private let analyticsProvider: AnalyticsProvider?
    private let onClose: () -> Void
    private let onContinue: (MultichainSwapConfirmationInput) -> Void
    private let onInitialSelectionUnavailable: () -> Void
    private let onQuoteProviderError: (String) -> Void
    private let onTonMaxAmountUnavailable: () -> Void
    private let onOpenRaffle: () -> Void

    private let quoteViewModel: MultichainSwapQuoteViewModel
    private let calculator: MultichainSwapAmountCalculator
    private let stateMaker: MultichainSwapStateMaker

    @Published private(set) var state: MultichainSwapViewModelState = .shimmer
    @Published private(set) var rafflePresentation: MysteryRafflePresentation?
    @Published private(set) var focusRequestID: Int = 0

    private var inputs: MultichainSwapInputs?
    private var quoteSnapshot: MultichainSwapQuoteSnapshot = .initial()
    private var initialAssetsTask: Task<Void, Never>?

    var onRequestPickSendToken: (() -> Void)?
    var onRequestPickReceiveToken: (() -> Void)?
    var onCircularProgressComplete: (() -> Void)?

    init(
        amountFormatter: AmountFormatter,
        multichainSwapService: MultichainSwapService,
        multichainState: MultichainWalletState,
        wallet: Wallet,
        defaultAssetsService: MultichainSwapDefaultAssetsService,
        displayCurrency: Currency = .defaultCurrency,
        isSwapKitEnabled: Bool = false,
        raffleStore: RaffleStore? = nil,
        analyticsProvider: AnalyticsProvider? = nil,
        onClose: @escaping () -> Void = {},
        onContinue: @escaping (MultichainSwapConfirmationInput) -> Void = { _ in },
        onInitialSelectionUnavailable: @escaping () -> Void = {},
        onQuoteProviderError: @escaping (String) -> Void = { _ in },
        onTonMaxAmountUnavailable: @escaping () -> Void = {},
        onOpenRaffle: @escaping () -> Void = {}
    ) {
        self.amountFormatter = amountFormatter
        self.multichainState = multichainState
        self.wallet = wallet
        self.defaultAssetsService = defaultAssetsService
        self.analyticsProvider = analyticsProvider
        self.onClose = onClose
        self.onContinue = onContinue
        self.onInitialSelectionUnavailable = onInitialSelectionUnavailable
        self.onQuoteProviderError = onQuoteProviderError
        self.onTonMaxAmountUnavailable = onTonMaxAmountUnavailable
        self.onOpenRaffle = onOpenRaffle

        let calculator = MultichainSwapAmountCalculator(
            amountFormatter: amountFormatter,
            displayCurrency: displayCurrency
        )
        self.calculator = calculator
        self.stateMaker = MultichainSwapStateMaker(
            calculator: calculator,
            validator: MultichainSwapValidator(
                calculator: calculator,
                multichainState: multichainState
            )
        )
        self.quoteViewModel = MultichainSwapQuoteViewModel(
            multichainSwapService: multichainSwapService,
            amountFormatter: amountFormatter,
            requestedAggregators: MultichainSwapQuoteRequest.requestedAggregators(
                isSwapKitEnabled: isSwapKitEnabled
            )
        )
        self.quoteViewModel.onSnapshotChange = { [weak self] snapshot in
            self?.applyQuoteSnapshot(snapshot)
        }
        self.quoteViewModel.onProviderErrorMessage = { [weak self] message in
            self?.onQuoteProviderError(message)
        }
        raffleObserver = MysteryRafflePresentationObserver(
            raffleStore: raffleStore
        ) { [weak self] presentation in
            self?.rafflePresentation = presentation
            self?.logRaffleBannerViewIfNeeded()
        }
        loadInitialAssets()
    }

    deinit {
        initialAssetsTask?.cancel()
    }

    func requestFocusOnAppear() {
        focusRequestID += 1
    }

    func close() {
        initialAssetsTask?.cancel()
        onClose()
    }

    func retryLoading() {
        loadInitialAssets()
    }

    func openRaffle() {
        analyticsProvider?.log(RaffleBannerClick(source: .swapPromo))
        onOpenRaffle()
    }

    /// Fires `raffle_banner_view` once per raffle id while the swap promo is eligible.
    /// The observer re-derives on a timer, so dedup on id.
    private func logRaffleBannerViewIfNeeded() {
        guard let presentation = rafflePresentation, presentation.shouldShowSwapPromo else { return }
        guard shownRaffleBannerIDs.insert(presentation.raffle.id).inserted else { return }
        analyticsProvider?.log(RaffleBannerView(source: .swapPromo))
    }

    func continueSwap() {
        guard let input = makeConfirmationInput() else {
            return
        }
        Log.multichainSwap.i(
            "swap confirmation opened: \(input.quoteState.quote.quoteId) / \(input.quoteState.route.routeId)"
        )
        onContinue(input)
    }

    func notifyCircularProgressCompleted() {
        guard case let .loaded(loadedState) = state,
              loadedState.quote.quoteState == .ready
        else {
            return
        }
        onCircularProgressComplete?()
        quoteViewModel.notifyCircularProgressCompleted()
    }

    func swapTokens() {
        guard var inputs else {
            return
        }
        let previousSendAsset = inputs.sendAsset
        let previousSendCryptoAmount = calculator.sourceAmount(
            inputs: inputs,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
        ).flatMap { sourceAmount -> String? in
            guard sourceAmount > 0 else {
                return nil
            }
            return calculator.cryptoInputAmountString(
                amount: sourceAmount,
                decimals: previousSendAsset.asset.decimals
            )
        } ?? ""
        let previousReceiveAmount = inputs.receiveAmount
        let receiveAmountIsZero = (calculator.cryptoAmount(
            text: previousReceiveAmount,
            decimals: inputs.receiveAsset.asset.decimals
        ) ?? 0) == 0

        inputs = inputs.settingSendAsset(inputs.receiveAsset)
        inputs.receiveAsset = previousSendAsset
        inputs.sendAmountInputMode = .crypto
        inputs.receiveAmountInputMode = .crypto
        // With nothing to move across (no quote yet, or it failed) the typed amount stays
        // in place instead of being wiped, and the new pair is re-quoted for it.
        inputs = inputs.settingSendAmount(receiveAmountIsZero ? previousSendCryptoAmount : previousReceiveAmount)
        inputs.receiveAmount = ""
        commit(inputs, resettingQuote: true)

        refreshQuote(recreatePair: true, debounce: false)
        if !receiveAmountIsZero {
            carryReceiveAmount(previousSendCryptoAmount)
        }
    }

    func requestPickSendToken() {
        guard inputs != nil else {
            return
        }
        onRequestPickSendToken?()
    }

    func requestPickReceiveToken() {
        guard inputs != nil else {
            return
        }
        onRequestPickReceiveToken?()
    }

    func updateSendAmount(_ sendAmount: String) {
        guard var inputs, inputs.sendAmount != sendAmount else {
            return
        }
        inputs = inputs.settingSendAmount(sendAmount)
        commit(inputs)
        refreshQuote(recreatePair: false, debounce: true)
    }

    func updateReceiveAmount(_ receiveAmount: String) {
        guard var inputs, inputs.receiveAmount != receiveAmount else {
            return
        }
        inputs.receiveAmount = receiveAmount
        commit(inputs)
    }

    func applySendAsset(_ asset: MultichainAsset) {
        guard var inputs else {
            return
        }
        let previousSendAsset = inputs.sendAsset
        inputs = inputs.settingSendAsset(asset)
        let flipped = inputs.receiveAsset.asset.assetId == asset.asset.assetId
        if flipped {
            inputs.receiveAsset = previousSendAsset
        }
        inputs = normalizedInputModes(inputs)
        inputs.receiveAmount = ""
        commit(inputs, resettingQuote: true)

        refreshQuote(recreatePair: true, debounce: false)
    }

    func applyReceiveAsset(_ asset: MultichainAsset) {
        guard var inputs else {
            return
        }
        let previousReceiveAsset = inputs.receiveAsset
        inputs.receiveAsset = asset
        let flipped = inputs.sendAsset.asset.assetId == asset.asset.assetId
        if flipped {
            inputs = inputs.settingSendAsset(previousReceiveAsset)
        }
        inputs = normalizedInputModes(inputs)
        inputs.receiveAmount = ""
        commit(inputs, resettingQuote: true)

        refreshQuote(recreatePair: true, debounce: false)
    }

    func applyMaxSend() {
        guard var inputs else {
            return
        }
        let maxAmount = MultichainSwapMaxAmount.maxSwapInputAmount(for: inputs.sendAsset)
        guard maxAmount > 0 else {
            if MultichainSwapMaxAmount.tonMaxUnavailableDueToFeeReserve(for: inputs.sendAsset) {
                onTonMaxAmountUnavailable()
            }
            return
        }
        inputs = inputs.settingSendAmount(
            calculator.inputAmountString(
                sourceAmount: maxAmount,
                mode: inputs.sendAmountInputMode,
                asset: inputs.sendAsset,
                usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
            ),
            isMax: true
        )
        commit(inputs)
        refreshQuote(recreatePair: false, debounce: true)
    }

    func toggleRateDisplayDirection() {
        guard inputs != nil else {
            return
        }
        quoteViewModel.toggleRateDisplayDirection()
    }

    func toggleSendAmountInputMode() {
        guard var inputs else {
            return
        }
        let nextMode = inputs.sendAmountInputMode.toggled
        guard nextMode != .fiat || calculator.fiatRates.hasFiatPrice(
            for: inputs.sendAsset,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
        ) else {
            return
        }
        let sourceAmount = calculator.sourceAmount(
            inputs: inputs,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
        )
        inputs = inputs.switchingSendAmountInputMode(
            to: nextMode,
            convertedAmount: calculator.inputAmountString(
                sourceAmount: sourceAmount ?? .zero,
                mode: nextMode,
                asset: inputs.sendAsset,
                usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
            )
        )
        commit(inputs)
        // Switching the currency the amount is written in leaves the amount itself alone,
        // so a ready quote is kept instead of being dropped for an identical one.
        guard calculator.sourceAmount(
            inputs: inputs,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
        ) != sourceAmount else {
            return
        }
        refreshQuote(recreatePair: false, debounce: true)
    }

    func toggleReceiveAmountInputMode() {
        guard var inputs else {
            return
        }
        let nextMode = inputs.receiveAmountInputMode.toggled
        guard nextMode != .fiat || calculator.fiatRates.canRenderFiat(
            for: inputs.receiveAsset,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs),
            fallbackUsdPrice: quoteSnapshot.destinationUsdPrice
        ) else {
            return
        }
        inputs.receiveAmountInputMode = nextMode
        commit(inputs)
    }

    func makeConfirmationInput() -> MultichainSwapConfirmationInput? {
        guard case let .loaded(loadedState) = state, let inputs else {
            return nil
        }
        guard let selectedQuote = loadedState.quote.selectedQuote,
              let selectedRoute = loadedState.quote.selectedRoute,
              loadedState.validationState == .valid,
              loadedState.quote.quoteState == .ready,
              selectedRoute.dateExpire > Date()
        else {
            return nil
        }
        let sourceAmount = selectedRoute.sourceAmount.flatMap { BigUInt($0) }
            ?? calculator.sourceAmount(
                inputs: inputs,
                usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
            )
        guard let sourceAmount,
              sourceAmount > 0,
              sourceAmount <= inputs.sendAsset.balance,
              BigUInt(selectedRoute.estimatedDestinationAmount) != nil
        else {
            return nil
        }
        return MultichainSwapConfirmationInput(
            userInput: MultichainSwapConfirmationUserInput(
                sendAmount: calculator.cryptoInputAmountString(
                    amount: sourceAmount,
                    decimals: inputs.sendAsset.asset.decimals
                ),
                rateText: loadedState.quote.rateText.stringValue,
                sourceAmount: sourceAmount,
                sendAsset: inputs.sendAsset,
                receiveAsset: inputs.receiveAsset,
                slippage: inputs.slippage,
                isMax: inputs.isMaxSend
            ),
            quoteState: MultichainSwapConfirmationQuoteState(
                quote: selectedQuote,
                route: selectedRoute
            )
        )
    }
}

private extension MultichainSwapViewModel {
    func commit(_ inputs: MultichainSwapInputs, resettingQuote: Bool = false) {
        self.inputs = inputs
        if resettingQuote {
            quoteSnapshot = .initial()
        }
        render()
    }

    func render() {
        guard let inputs else {
            return
        }
        state = .loaded(stateMaker.make(inputs: inputs, quote: quoteSnapshot))
    }

    func effectiveUsdFiatRate(inputs: MultichainSwapInputs) -> Decimal? {
        calculator.fiatRates.effectiveUsdFiatRate(inputs: inputs, quote: quoteSnapshot)
    }

    /// Realigns both amount fields to crypto when an asset change — including a
    /// flip that swaps both sides — leaves a field in fiat mode for an asset that
    /// can no longer be priced. Send fiat text is dropped since it cannot be
    /// reinterpreted as crypto; the receive amount is always stored as crypto.
    func normalizedInputModes(_ inputs: MultichainSwapInputs) -> MultichainSwapInputs {
        var inputs = inputs
        let usdFiatRate = effectiveUsdFiatRate(inputs: inputs)
        if inputs.sendAmountInputMode == .fiat,
           !calculator.fiatRates.canRenderFiat(for: inputs.sendAsset, usdFiatRate: usdFiatRate)
        {
            inputs.sendAmountInputMode = .crypto
            inputs = inputs.settingSendAmount("")
        }
        if inputs.receiveAmountInputMode == .fiat,
           !calculator.fiatRates.canRenderFiat(for: inputs.receiveAsset, usdFiatRate: usdFiatRate)
        {
            inputs.receiveAmountInputMode = .crypto
        }
        return inputs
    }

    func applyQuoteSnapshot(_ snapshot: MultichainSwapQuoteSnapshot) {
        quoteSnapshot = snapshot
        guard var inputs else {
            return
        }
        inputs.receiveAmount = stateMaker.resolvedReceiveAmount(
            previous: inputs.receiveAmount,
            quote: snapshot,
            receiveAsset: inputs.receiveAsset
        )
        self.inputs = inputs
        render()
        logFiatContextIfQuoteReady(inputs: inputs, snapshot: snapshot)
    }

    /// Diagnostic trail for missing fiat lines: every input of the fiat
    /// resolution in one line, logged once per ready quote.
    func logFiatContextIfQuoteReady(
        inputs: MultichainSwapInputs,
        snapshot: MultichainSwapQuoteSnapshot
    ) {
        guard snapshot.quoteState == .ready else {
            return
        }
        var rateTextResolved = "n/a"
        if case let .loaded(loadedState) = state {
            rateTextResolved = loadedState.receiveCardRateText == nil ? "nil" : "present"
        }
        Log.multichainSwap.i(
            "quote fiat context",
            extraInfo: [
                "displayCurrency": calculator.displayCurrency.code,
                "usdFiatRate": inputs.usdFiatRate?.description ?? "nil",
                "sourceUsdPrice": snapshot.sourceUsdPrice.map { "\($0)" } ?? "nil",
                "destinationUsdPrice": snapshot.destinationUsdPrice.map { "\($0)" } ?? "nil",
                "receiveAssetPriceKeys": inputs.receiveAsset.price.prices.keys.sorted().joined(separator: ","),
                "receiveAmountText": inputs.receiveAmount,
                "receiveCardRateText": rateTextResolved,
            ]
        )
    }

    func carryReceiveAmount(_ receiveAmount: String) {
        guard var inputs,
              quoteSnapshot.quoteState != .ready,
              inputs.receiveAmount != receiveAmount
        else {
            return
        }
        inputs.receiveAmount = receiveAmount
        self.inputs = inputs
        render()
    }
}

private extension MultichainSwapViewModel {
    func loadInitialAssets() {
        initialAssetsTask?.cancel()
        inputs = nil
        quoteSnapshot = .initial()
        state = .shimmer
        quoteViewModel.reset()

        let defaultAssetsService = defaultAssetsService
        initialAssetsTask = Task { [weak self] in
            do {
                let initialAssets = try await defaultAssetsService.load()
                guard !Task.isCancelled, let self else {
                    return
                }
                applyInitialAssets(initialAssets)
            } catch {
                guard !Task.isCancelled, let self else {
                    return
                }
                Log.multichainSwap.w("initial assets loading failed", error: error)
                state = .error
            }
        }
    }

    func applyInitialAssets(_ initialAssets: MultichainSwapInitialAssets) {
        commit(MultichainSwapInputs(initialAssets: initialAssets), resettingQuote: true)
        refreshQuote(recreatePair: true, debounce: false)
        if initialAssets.hasUnavailableInitialSelection {
            onInitialSelectionUnavailable()
        }
    }
}

private extension MultichainSwapViewModel {
    func refreshQuote(recreatePair: Bool, debounce: Bool) {
        guard let inputs else {
            quoteViewModel.setPair(nil)
            return
        }
        if recreatePair {
            quoteViewModel.setPair(pairContext(for: inputs))
        }
        quoteViewModel.updateSourceAmount(
            quoteSourceAmount(for: inputs),
            debounce: debounce
        )
    }

    func pairContext(for inputs: MultichainSwapInputs) -> MultichainSwapQuotePairContext? {
        guard let sourceChain = inputs.sendAsset.asset.chain,
              let destinationChain = inputs.receiveAsset.asset.chain,
              let senderAddress = multichainState.address(for: sourceChain, preferredType: wallet.preferredMultichainAddressType(for: sourceChain)),
              let recipientAddress = multichainState.address(for: destinationChain, preferredType: wallet.preferredMultichainAddressType(for: destinationChain))
        else {
            return nil
        }
        return MultichainSwapQuotePairContext(
            source: MultichainSwapQuoteItem(
                assetId: inputs.sendAsset.asset.assetId,
                symbol: inputs.sendAsset.swapDisplaySymbol,
                decimals: inputs.sendAsset.asset.decimals,
                chain: sourceChain,
                address: senderAddress
            ),
            destination: MultichainSwapQuoteItem(
                assetId: inputs.receiveAsset.asset.assetId,
                symbol: inputs.receiveAsset.swapDisplaySymbol,
                decimals: inputs.receiveAsset.asset.decimals,
                chain: destinationChain,
                address: recipientAddress
            ),
            slippageBps: DefaultMultichainSwapSlippageService(
                sourceAssetId: inputs.sendAsset.asset.assetId,
                sourceChain: sourceChain,
                slippage: inputs.slippage
            ).defaultBps,
            walletId: multichainState.walletId
        )
    }

    func quoteSourceAmount(for inputs: MultichainSwapInputs) -> BigUInt? {
        guard let sourceAmount = calculator.sourceAmount(
            inputs: inputs,
            usdFiatRate: effectiveUsdFiatRate(inputs: inputs)
        ),
            sourceAmount > 0,
            sourceAmount <= inputs.sendAsset.balance,
            pairContext(for: inputs) != nil
        else {
            return nil
        }
        return sourceAmount
    }
}

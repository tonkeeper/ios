import Combine
import Foundation
import PerpsModels
import SwiftUI
import TKLocalize
import TKLogging

@MainActor
final class PerpsOpenPositionViewModel: ObservableObject {
    enum SizeDisplayMode: Equatable {
        case usd
        case token
    }

    enum ViewState: Equatable {
        case loading
        case ready
    }

    enum AccountState: Equatable {
        case resolving
        case needsDeposit(balance: Double?)
        case ready(balance: Double)
    }

    /// Everything the user has typed or chosen, plus what the market read and the
    /// planner answered for it. The single source the screen renders from.
    struct State: Equatable {
        var viewState: ViewState = .loading
        var account: AccountState = .resolving
        var orderType: PerpsOrderType = .market
        var amountText: String = ""
        var sizeMode: SizeDisplayMode = .usd
        var leverage: Double
        /// Trigger prices as last set. A leg with a typed ROI follows the price the
        /// order would open at, so read the draft through `autoClose(in:)`.
        var autoClose: PerpsAutoClose?
        var autoCloseROIInput: PerpsAutoCloseROIInput = .none
        var autoCloseWarningText: String?
        var reviewWarningText: String?
        var limitPrice: Double?
        var context: PerpsOpenMarketContext?
        var livePrice: Double?
        /// Last liquidation price the planner reviewed for this draft. Not derived
        /// here: the client does not compute trade figures.
        var liquidationPrice: Double?
    }

    @Published private(set) var state: State
    @Published private(set) var amountFocusState: PerpsAmountFocusState = .active(version: 0)
    @Published private(set) var isReviewInFlight = false

    let side: PerpsTradeSide
    let marketId: Int64

    var onClose: (() -> Void)?
    var onDeposit: (() -> Void)?
    var onOpenLeverage: ((PerpsLeverageSheetContext) -> Void)?
    var onOpenAutoClose: ((PerpsAutoCloseSheetContext) -> Void)?
    var onReview: ((PerpsConfirmContext) -> Void)?
    var onInvalidAutoClose: ((PerpsAutoCloseValidation.InvalidLegs) -> Void)?
    var onOrderNotPlaced: (() -> Void)?
    var onOpenOrderType: ((PerpsOrderType) -> Void)?
    var onOpenSetLimitPrice: ((PerpsSetLimitPriceContext) -> Void)?
    var onLoadFailed: (() -> Void)?
    var ensureAccountReady: (@MainActor () async -> Bool)?

    private let service: PerpsTradingService
    private let accountStore: any PerpsAccountStoring
    private let priceFeed: PerpsMarketPriceFeed
    private let draftReviewer = PerpsDraftReviewer()
    private let reviewerLoadedSubject = PassthroughSubject<Void, Never>()
    private var hasUserAdjustedLeverage = false
    private var isLoadingMarket = false
    private var didAppear = false

    private let format: PerpsFormatting

    private static let quoteDecimals = 6
    private static let minimumOpenMarginUsd: Double = 1

    init(
        marketId: Int64,
        side: PerpsTradeSide,
        service: PerpsTradingService,
        accountStore: any PerpsAccountStoring,
        marketsStore: any PerpsMarketsStoring,
        initialLeverage: Double,
        format: PerpsFormatting
    ) {
        self.format = format
        self.marketId = marketId
        self.side = side
        self.service = service
        self.accountStore = accountStore
        priceFeed = PerpsMarketPriceFeed(marketId: marketId, store: marketsStore)
        state = State(leverage: initialLeverage)
        observeAccount()
        priceFeed.observe(self) { $0.applyLivePrice() }
    }

    // MARK: - Lifecycle

    func onAppear() {
        accountStore.resolveIfNeeded()
        applyAccount(accountStore.currentWalletState())
        priceFeed.subscribe()
        applyLivePrice()
        Task { [weak self] in await self?.loadMarketIfNeeded() }
    }

    func onDisappear() {
        priceFeed.unsubscribe()
    }

    func requestFocusOnAppear() {
        didAppear = true
        requestAmountFocus()
    }

    func requestAmountFocus() {
        amountFocusState = amountFocusState.activated(requestFocus: didAppear && viewState == .ready)
    }

    func suppressAmountFocus() {
        amountFocusState = amountFocusState.suppressingFocus()
    }

    // MARK: - Draft

    var viewState: ViewState {
        state.viewState
    }

    var account: AccountState {
        state.account
    }

    var orderType: PerpsOrderType {
        state.orderType
    }

    var amountText: String {
        state.amountText
    }

    var sizeMode: SizeDisplayMode {
        state.sizeMode
    }

    var leverage: Double {
        state.leverage
    }

    var autoClose: PerpsAutoClose? {
        autoClose(in: state)
    }

    var autoCloseROIInput: PerpsAutoCloseROIInput {
        state.autoCloseROIInput
    }

    var limitPrice: Double? {
        state.limitPrice
    }

    var context: PerpsOpenMarketContext? {
        state.context
    }

    var warningText: String? {
        hasInvalidAutoCloseROI(in: state)
            ? TKLocales.Perps.Error.autoCloseInvalid
            : state.autoCloseWarningText ?? state.reviewWarningText
    }

    var effectivePrice: Double {
        effectivePrice(in: state)
    }

    var marginUsd: Double {
        marginUsd(in: state)
    }

    var sizeUsd: Double {
        marginUsd * leverage
    }

    var canDeposit: Bool {
        if case .needsDeposit = state.account { return true }
        return false
    }

    var isReviewEnabled: Bool {
        !isReviewInFlight && isDraftReviewable
    }

    /// Whether the draft itself could be sent. Separate from `isReviewEnabled`, which
    /// also keeps the button down while a review is already in flight — the review
    /// that is in flight must still be able to ask this.
    var isDraftReviewable: Bool {
        guard state.viewState == .ready,
              !hasInvalidAutoCloseROI(in: state),
              marginUsd(in: state) > 0,
              effectivePrice(in: state) > 0,
              meetsMinimumMargin(in: state)
        else {
            return false
        }
        if state.orderType == .limit, !(state.limitPrice ?? 0 > 0) { return false }
        if case let .ready(balance) = state.account { return marginUsd(in: state) <= balance }
        return false
    }

    /// The planner's number for a leverage the draft has not committed to, for the
    /// leverage sheet's slider. Synchronous: the inputs are already loaded.
    func reviewedLiquidation(forLeverage leverage: Double) -> Double? {
        guard let context = state.context else { return nil }
        var draft = state
        draft.leverage = leverage
        let price = reviewedLiquidation(in: probingDraft(draft), context: context)
        if draftReviewer.needsLoad {
            loadReviewerIfNeeded()
        }
        return price
    }

    var reviewerLoaded: AnyPublisher<Void, Never> {
        reviewerLoadedSubject.eraseToAnyPublisher()
    }

    // MARK: - Display

    var titleText: String {
        let symbol = context?.symbol ?? ""
        let sideText = side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short
        return "\(sideText) \(symbol)".trimmingCharacters(in: .whitespaces)
    }

    var orderTypeText: String {
        switch orderType {
        case .market: return TKLocales.Perps.OrderType.market
        case .limit: return TKLocales.Perps.OrderType.limit
        }
    }

    var isLimitOrder: Bool {
        orderType == .limit
    }

    var headerPriceText: String {
        let price = effectivePrice
        guard price > 0 else { return "—" }
        return format.usd(price)
    }

    var sizeText: String? {
        switch sizeMode {
        case .usd: return format.usd(sizeUsd)
        case .token: return format.usd(marginUsd)
        }
    }

    var leverageText: String {
        format.leverage(leverage)
    }

    var balanceText: String? {
        switch account {
        case .resolving: return nil
        case let .needsDeposit(balance): return balance.map { format.usd($0) }
        case let .ready(balance): return format.usd(balance)
        }
    }

    var autoCloseSummary: String? {
        autoClose.flatMap { format.autoCloseSummary($0, typedROI: state.autoCloseROIInput) }
    }

    var balanceErrorText: String? {
        let margin = marginUsd
        guard viewState == .ready, margin > 0 else { return nil }
        if !meetsMinimumMargin(in: state) {
            return TKLocales.Perps.OpenPosition.minimumMargin(format.usd(minimumMarginUsd(in: state)))
        }
        switch account {
        case .resolving:
            return nil
        case .needsDeposit:
            return TKLocales.Perps.OpenPosition.insufficientFunds
        case let .ready(balance):
            return margin > balance ? TKLocales.Perps.OpenPosition.insufficientFunds : nil
        }
    }

    // MARK: - Intent

    func setAmount(_ text: String) {
        let decimals = state.sizeMode == .usd ? 2 : state.context?.sizeDecimals ?? 0
        let sanitized = decimals > 0
            ? PerpsDecimalInput.sanitize(text, decimals: decimals)
            : String(PerpsDecimalInput.sanitize(text, decimals: 1).prefix { $0 != "." })
        let isEdit = sanitized != state.amountText
        update {
            $0.amountText = sanitized
            if isEdit { $0.reviewWarningText = nil }
        }
    }

    func toggleSizeMode() {
        guard effectivePrice > 0 else { return }
        update { draft in
            switch draft.sizeMode {
            case .usd:
                draft.amountText = tokenText(forMarginUsd: marginUsd(in: draft), in: draft)
                draft.sizeMode = .token
            case .token:
                let margin = marginUsd(in: draft)
                draft.amountText = margin > 0 ? PerpsDecimalInput.usdText(margin) : ""
                draft.sizeMode = .usd
            }
            draft.reviewWarningText = nil
        }
    }

    func setMax() {
        guard case let .ready(balance) = state.account, balance > 0 else { return }
        update {
            switch $0.sizeMode {
            case .usd: $0.amountText = PerpsDecimalInput.usdText(balance)
            case .token: $0.amountText = tokenText(forMarginUsd: balance, in: $0)
            }
            $0.reviewWarningText = nil
        }
    }

    func applyOrderType(_ type: PerpsOrderType) {
        update { draft in
            draft.orderType = type
            if type == .market { draft.limitPrice = nil }
            draft.reviewWarningText = nil
            resetInvalidAutoCloseIfNeeded(in: &draft)
        }
    }

    func applyLimitPrice(_ price: Double) {
        update { draft in
            draft.limitPrice = price
            draft.orderType = .limit
            draft.reviewWarningText = nil
            resetInvalidAutoCloseIfNeeded(in: &draft)
        }
    }

    func applyLeverage(_ value: Double) {
        hasUserAdjustedLeverage = true
        update { draft in
            draft.leverage = value
            draft.reviewWarningText = nil
            resetInvalidAutoCloseIfNeeded(in: &draft)
        }
    }

    /// A nil `roiInput` keeps what was typed for the legs that remain.
    func applyAutoClose(_ value: PerpsAutoClose?, roiInput: PerpsAutoCloseROIInput? = nil) {
        guard let value, !value.isEmpty else {
            update {
                $0.autoClose = nil
                $0.autoCloseWarningText = nil
                $0.reviewWarningText = nil
            }
            return
        }
        var probe = state
        probe.autoClose = value
        probe.autoCloseROIInput = roiInput ?? state.autoCloseROIInput
        let resolved = autoClose(in: probe)
        let warning = hasInvalidAutoCloseROI(in: probe) ? nil : resolved.flatMap { autoCloseWarning(for: $0, in: probe) }
        update {
            $0.autoClose = warning == nil ? resolved : resolved.flatMap { self.keepingValidLegs($0, in: probe) }
            $0.autoCloseROIInput = probe.autoCloseROIInput
            $0.autoCloseWarningText = warning?.message
            $0.reviewWarningText = nil
        }
    }

    func openLeverage() {
        guard let context = state.context else { return }
        onOpenLeverage?(PerpsLeverageSheetContext(
            marketId: marketId,
            side: side,
            bounds: context.leverageBounds,
            current: state.leverage
        ))
    }

    func openOrderType() {
        onOpenOrderType?(orderType)
    }

    func openSetLimitPrice() {
        guard let context = state.context else { return }
        onOpenSetLimitPrice?(PerpsSetLimitPriceContext(
            marketId: marketId,
            side: side,
            priceDecimals: context.priceDecimals,
            referencePrice: referencePrice(in: state),
            initialLimitPrice: state.limitPrice
        ))
    }

    func openAutoClose() {
        guard let context = state.context else { return }
        onOpenAutoClose?(PerpsAutoCloseSheetContext(
            marketId: marketId,
            side: side,
            entryPrice: effectivePrice,
            referencePrice: effectivePrice,
            leverage: state.leverage,
            baseSize: steppedBaseSize(in: state),
            liquidationPrice: state.liquidationPrice,
            priceDecimals: context.priceDecimals,
            draft: autoClose,
            roiInput: state.autoCloseROIInput,
            livePriceMarketId: isLimitOrder ? nil : marketId
        ))
    }

    func deposit() {
        onDeposit?()
    }

    func close() {
        onClose?()
    }

    func review() {
        guard !isReviewInFlight else { return }
        suppressAmountFocus()
        isReviewInFlight = true
        Task { [weak self] in
            guard let self else { return }
            defer { isReviewInFlight = false }
            guard await ensureAccountReady?() ?? true else {
                requestAmountFocus()
                return
            }
            switch await confirmContext() {
            case let .success(context):
                update { $0.reviewWarningText = nil }
                let limit = context.intent.limitPrice
                Log.perps.i("OpenPosition: review → confirm market=\(marketId) side=\(side) lev=\(context.intent.leverage)x \(limit.map { "limit=\($0)" } ?? "market")")
                onReview?(context)
            case let .failure(error):
                Log.perps.w("OpenPosition: review failed market=\(marketId) side=\(side) margin=\(marginUsd) lev=\(state.leverage)x \(state.limitPrice.map { "limit=\($0)" } ?? "market") — \(error)")
                if case .invalidAmount = error, let load = reviewerLoad(for: probe(state)) {
                    await draftReviewer.reload(load)
                    applyLoadedReviewer()
                }
                let message: String? = if case .invalidAmount = error, !meetsMinimumMargin(in: state) {
                    nil
                } else {
                    PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.openFailed)
                }
                update { $0.reviewWarningText = message }
                switch error {
                case let .invalidAutoClose(leg?) where onInvalidAutoClose != nil:
                    onInvalidAutoClose?(await refusedAutoCloseLegs(leg))
                case .slippageExceeded where onOrderNotPlaced != nil:
                    onOrderNotPlaced?()
                default:
                    requestAmountFocus()
                }
            }
        }
    }

    func continueWithoutAutoClose(_ invalid: PerpsAutoCloseValidation.InvalidLegs) {
        if let autoClose {
            applyAutoClose(PerpsAutoCloseValidation.stripping(autoClose, removing: invalid))
        }
        review()
    }

    func setReviewWarning(_ text: String?) {
        update { $0.reviewWarningText = text }
    }
}

private extension PerpsOpenPositionViewModel {
    func loadMarketIfNeeded() async {
        guard state.context == nil, !isLoadingMarket else { return }
        isLoadingMarket = true
        update { $0.viewState = .loading }
        Log.perps.i("OpenPosition: load start market=\(marketId) side=\(side)")

        guard let context = await service.openMarketContext(marketId: marketId, side: side) else {
            isLoadingMarket = false
            Log.perps.w("OpenPosition: load failed market=\(marketId) → closing")
            onLoadFailed?()
            return
        }

        update {
            $0.context = context
            if !hasUserAdjustedLeverage {
                $0.leverage = context.defaultLeverage
            }
            $0.viewState = .ready
        }
        isLoadingMarket = false
        Log.perps.i("OpenPosition: ready market=\(marketId) price=\(context.displayPrice) lev=\(state.leverage)x")
        if amountFocusState.isActive {
            requestAmountFocus()
        }
    }

    /// Re-plans against a fresh read before handing the draft to the confirm screen,
    /// and refuses if the draft moved while that read was in flight.
    func confirmContext() async -> Result<PerpsConfirmContext, PerpsTradingError> {
        guard isDraftReviewable, let context = state.context else {
            return .failure(.validation("amount is empty or invalid"))
        }
        let draft = state
        let intent = openIntent(in: draft, context: context)
        switch await service.previewOpenMarket(intent) {
        case let .success(review):
            var current = state
            current.livePrice = draft.livePrice
            guard current.context == context,
                  openIntent(in: current, context: context) == intent
            else {
                return .failure(.stalePreparedTransaction)
            }
            return .success(PerpsConfirmContext(
                intent: intent,
                sizeDecimals: context.sizeDecimals,
                priceDecimals: context.priceDecimals,
                review: review
            ))
        case let .failure(error):
            return .failure(error)
        }
    }

    func refusedAutoCloseLegs(_ leg: PerpsTriggerOrderSummary.Kind) async -> PerpsAutoCloseValidation.InvalidLegs {
        guard let autoClose, let context = state.context else {
            return PerpsAutoCloseValidation.InvalidLegs(leg)
        }
        return await PerpsAutoCloseValidation.refusedLegs(autoClose, refused: leg) { rest in
            var probe = state
            probe.autoClose = rest
            return await service.previewOpenMarket(openIntent(in: probe, context: context))
        }
    }

    func referencePrice(in draft: State) -> Double {
        draft.livePrice ?? draft.context?.displayPrice ?? 0
    }

    func effectivePrice(in draft: State) -> Double {
        if draft.orderType == .limit, let limitPrice = draft.limitPrice, limitPrice > 0 {
            return limitPrice
        }
        return referencePrice(in: draft)
    }

    func marginText(in draft: State) -> String {
        switch draft.sizeMode {
        case .usd:
            return PerpsDecimalInput.normalized(draft.amountText)
        case .token:
            let price = effectivePrice(in: draft)
            let base = baseSize(in: draft)
            guard base > 0, price > 0, draft.leverage > 0 else { return "" }
            return PerpsDecimalInput.text(base * price / draft.leverage, decimals: Self.quoteDecimals)
        }
    }

    func marginUsd(in draft: State) -> Double {
        PerpsDecimalInput.double(marginText(in: draft)) ?? 0
    }

    func baseSize(in draft: State) -> Double {
        if draft.sizeMode == .token {
            return PerpsDecimalInput.double(draft.amountText) ?? 0
        }
        let price = effectivePrice(in: draft)
        guard price > 0 else { return 0 }
        return marginUsd(in: draft) * draft.leverage / price
    }

    func tokenText(forMarginUsd margin: Double, in draft: State) -> String {
        var probe = draft
        probe.sizeMode = .usd
        probe.amountText = PerpsDecimalInput.text(margin, decimals: Self.quoteDecimals)
        let base = steppedBaseSize(in: probe)
        guard base > 0 else { return "" }
        return PerpsDecimalInput.text(base, decimals: draft.context?.sizeDecimals ?? 0)
    }

    /// Both minimums the venue holds, measured on the size it would actually place:
    /// the order is cut to the market's size step, so a draft that clears a minimum
    /// only before that cut is one the planner refuses after it.
    func meetsMinimumSize(in draft: State) -> Bool {
        guard let context = draft.context else { return true }
        let price = effectivePrice(in: draft)
        guard price > 0 else { return true }
        let size = steppedBaseSize(in: draft)
        guard draft.orderType == .limit else { return size > 0 }
        if context.minBaseSize > 0, size < context.minBaseSize { return false }
        if context.minNotionalUsd > 0, size * price < context.minNotionalUsd { return false }
        return true
    }

    func minimumMarginUsd(in draft: State) -> Double {
        let planned = draft.context
            .flatMap { draftReviewer.current?.minimumOpenMarginUsd(openIntent(in: draft, context: $0)) }
            .map { ($0 * 100 - 1e-6).rounded(.up) / 100 } ?? 0
        return max(Self.minimumOpenMarginUsd, planned)
    }

    func meetsMinimumMargin(in draft: State) -> Bool {
        marginUsd(in: draft) >= minimumMarginUsd(in: draft) - 1e-9
    }

    func steppedBaseSize(in draft: State) -> Double {
        let size = baseSize(in: draft)
        guard draft.sizeMode == .usd, let sizeDecimals = draft.context?.sizeDecimals, sizeDecimals >= 0 else { return size }
        let step = pow(10.0, Double(sizeDecimals))
        return (size * step).rounded(.down) / step
    }

    func reviewedLiquidation(in draft: State, context: PerpsOpenMarketContext) -> Double? {
        guard let reviewer = draftReviewer.current else { return nil }
        return reviewer.reviewOpen(openIntent(in: draft, context: context))?.liquidationPrice
    }

    /// Reloads what a review reads. Called when there is nothing loaded yet and when
    /// the planner stops answering for the current draft — a stale observation, or a
    /// size the loaded book slice no longer covers.
    func probingDraft(_ draft: State) -> State {
        // The planner refuses a size below the market minimum, while an isolated
        // liquidation price does not depend on size, so such a draft is planned at the minimum.
        guard marginUsd(in: draft) <= 0 || !meetsMinimumSize(in: draft) || !meetsMinimumMargin(in: draft) else { return draft }
        return probe(draft)
    }

    func probe(_ draft: State) -> State {
        var probe = draft
        probe.sizeMode = .usd
        probe.amountText = PerpsDecimalInput.usdText(probeMarginUsd(in: draft))
        return probe
    }

    func probeMarginUsd(in draft: State) -> Double {
        guard let context = draft.context else { return 1 }
        let price = effectivePrice(in: draft)
        guard price > 0 else { return 1 }
        let leverage = max(draft.leverage, 1)
        let step = context.sizeDecimals >= 0 ? pow(10.0, -Double(context.sizeDecimals)) : 0
        let minimumBase = max(context.minBaseSize, context.minNotionalUsd / price)
        let margin = (minimumBase + step) * max(price, referencePrice(in: draft)) / leverage
        return max(1, (margin * 100).rounded(.up) / 100)
    }

    func loadReviewerIfNeeded() {
        guard let load = reviewerLoad(for: probingDraft(state)) else { return }
        draftReviewer.loadIfNeeded(load) { [weak self] in
            self?.applyLoadedReviewer()
        }
    }

    func reviewerLoad(for draft: State) -> (() async -> (any PerpetualReviewer)?)? {
        guard let context = draft.context else { return nil }
        let intent = openIntent(in: draft, context: context)
        return { [service] in
            do {
                return try await service.loadReviewer(for: intent).get()
            } catch {
                Log.perps.w("OpenPosition: reviewer load failed market=\(intent.marketId) — \(error)")
                return nil
            }
        }
    }

    func applyLoadedReviewer() {
        objectWillChange.send()
        refreshReviewedLiquidation()
        reviewerLoadedSubject.send()
    }

    func refreshReviewedLiquidation() {
        guard let context = state.context else {
            update { $0.liquidationPrice = nil }
            return
        }
        let price = reviewedLiquidation(in: probingDraft(state), context: context)
        if price == nil || draftReviewer.needsLoad {
            loadReviewerIfNeeded()
        }
        update {
            $0.liquidationPrice = price
            self.resetInvalidAutoCloseIfNeeded(in: &$0)
        }
    }

    func observeAccount() {
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.applyAccount(observer.accountStore.currentWalletState()) }
        }
    }

    func applyLivePrice() {
        guard let price = priceFeed.livePrice else { return }
        update { $0.livePrice = price }
    }

    func applyAccount(_ accountState: PerpsWalletAccountState) {
        let newValue: AccountState
        let label: String
        switch accountState {
        case .unresolved, .resolving:
            newValue = .resolving
            label = "resolving"
        case .unbound, .inactive:
            newValue = .needsDeposit(balance: nil)
            label = "needsDeposit(noAccount)"
        case let .active(value):
            let balance = PerpsMarketMath.optionalDouble(value.availableBalance) ?? 0
            newValue = balance > 0 ? .ready(balance: balance) : .needsDeposit(balance: balance)
            label = balance > 0 ? "ready" : "needsDeposit(empty)"
        }

        guard newValue != state.account else { return }
        update { $0.account = newValue }
        Log.perps.i("OpenPosition: account → \(label) market=\(marketId)")
    }

    func resetInvalidAutoCloseIfNeeded(in draft: inout State) {
        guard !hasInvalidAutoCloseROI(in: draft),
              let autoClose = autoClose(in: draft),
              !autoClose.isEmpty,
              let warning = autoCloseWarning(for: autoClose, in: draft)
        else {
            return
        }
        draft.autoClose = keepingValidLegs(autoClose, in: draft)
        draft.autoCloseWarningText = warning.message
    }

    func keepingValidLegs(_ autoClose: PerpsAutoClose, in draft: State) -> PerpsAutoClose? {
        let kept = PerpsAutoCloseValidation.stripping(
            autoClose,
            removing: PerpsAutoCloseValidation.invalidLegs(
                side: side,
                referencePrice: effectivePrice(in: draft),
                liquidationPrice: draft.liquidationPrice,
                autoClose: autoClose
            )
        )
        return kept.isEmpty ? nil : kept
    }

    func autoCloseWarning(for autoClose: PerpsAutoClose, in draft: State) -> PerpsAutoCloseValidation.Warning? {
        PerpsAutoCloseValidation.warning(
            side: side,
            referencePrice: effectivePrice(in: draft),
            liquidationPrice: draft.liquidationPrice,
            autoClose: autoClose,
            format: format
        )
    }

    func openIntent(in draft: State, context: PerpsOpenMarketContext) -> PerpsOpenMarketIntent {
        PerpsOpenMarketIntent(
            marketId: marketId,
            side: side,
            marginUsd: marginText(in: draft),
            leverage: draft.leverage,
            maxSlippage: context.maxSlippage,
            autoClose: autoClose(in: draft),
            limitPrice: draft.orderType == .limit ? draft.limitPrice : nil
        )
    }

    func autoClose(in draft: State) -> PerpsAutoClose? {
        guard let base = autoCloseBase(in: draft) else { return draft.autoClose }
        return draft.autoCloseROIInput.resolving(draft.autoClose, on: base)
    }

    func hasInvalidAutoCloseROI(in draft: State) -> Bool {
        guard let base = autoCloseBase(in: draft) else { return false }
        return draft.autoCloseROIInput.keeping(legsOf: draft.autoClose).hasInvalidPrice(on: base)
    }

    func autoCloseBase(in draft: State) -> PerpsAutoCloseBase? {
        guard let priceDecimals = draft.context?.priceDecimals else { return nil }
        return PerpsAutoCloseBase(
            side: side,
            entryPrice: effectivePrice(in: draft),
            leverage: draft.leverage,
            priceDecimals: priceDecimals
        )
    }

    func update(_ body: (inout State) -> Void) {
        var next = state
        body(&next)
        next.autoCloseROIInput = next.autoCloseROIInput.keeping(legsOf: next.autoClose)
        guard next != state else { return }
        let previous = state
        state = next
        if reviewInputsChanged(from: previous, to: next) {
            refreshReviewedLiquidation()
        }
    }

    func reviewInputsChanged(from old: State, to new: State) -> Bool {
        old.leverage != new.leverage
            || old.amountText != new.amountText
            || old.sizeMode != new.sizeMode
            || old.orderType != new.orderType
            || old.limitPrice != new.limitPrice
            || old.context != new.context
    }
}

extension PerpsOpenPositionViewModel: PerpsAmountFormViewModel {
    var isLoading: Bool {
        viewState == .loading
    }

    var priceTitle: String {
        isLimitOrder ? TKLocales.Perps.Order.price : TKLocales.Perps.OpenPosition.price
    }

    var priceText: String {
        headerPriceText
    }

    var isPriceTappable: Bool {
        isLimitOrder
    }

    var amountPrefix: String {
        sizeMode == .usd ? "$" : ""
    }

    var amountSuffix: String? {
        sizeMode == .token ? context?.symbol : nil
    }

    var sizeTitle: String {
        sizeMode == .usd ? TKLocales.Perps.OpenPosition.size : TKLocales.Perps.OpenPosition.margin
    }

    var orderTypeSwitchText: String? {
        orderTypeText
    }

    var balanceRow: PerpsAmountFormBalanceRow? {
        PerpsAmountFormBalanceRow(
            balanceText: balanceText,
            errorText: balanceErrorText,
            onMax: { [weak self] in self?.setMax() },
            onDeposit: { [weak self] in self?.deposit() }
        )
    }

    var optionRows: [PerpsAmountFormOptionRow] {
        [
            PerpsAmountFormOptionRow(
                id: "leverage",
                title: TKLocales.Perps.OpenPosition.leverage,
                value: leverageText,
                valueColor: .textPrimary,
                action: { [weak self] in self?.openLeverage() }
            ),
            PerpsAmountFormOptionRow(
                id: "autoClose",
                title: TKLocales.Perps.OpenPosition.autoClose,
                value: autoCloseSummary ?? TKLocales.Perps.OpenPosition.set,
                valueColor: autoCloseSummary == nil ? .textAccent : .textPrimary,
                action: { [weak self] in self?.openAutoClose() }
            ),
        ]
    }

    func tapPrice() {
        openSetLimitPrice()
    }

    func tapOrderType() {
        openOrderType()
    }
}

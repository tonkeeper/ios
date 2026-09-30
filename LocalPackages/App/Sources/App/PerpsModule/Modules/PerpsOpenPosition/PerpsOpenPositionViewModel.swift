import Combine
import Foundation
import KeeperCore
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
        var autoClose: PerpsAutoClose?
        var autoCloseWarningText: String?
        var reviewWarningText: String?
        var limitPrice: Double?
        var context: PerpsOpenMarketContext?
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
    var onOpenOrderType: ((PerpsOrderType) -> Void)?
    var onOpenSetLimitPrice: ((PerpsSetLimitPriceContext) -> Void)?
    var onLoadFailed: (() -> Void)?

    private let service: PerpsTradingService
    private let accountStore: PerpsAccountStore
    private let draftReviewer = PerpsDraftReviewer()
    private var hasUserAdjustedLeverage = false
    private var isLoadingMarket = false
    private var didAppear = false

    init(
        marketId: Int64,
        side: PerpsTradeSide,
        service: PerpsTradingService,
        accountStore: PerpsAccountStore,
        initialLeverage: Double
    ) {
        self.marketId = marketId
        self.side = side
        self.service = service
        self.accountStore = accountStore
        state = State(leverage: initialLeverage)
        observeAccount()
    }

    // MARK: - Lifecycle

    func onAppear() {
        accountStore.resolveIfNeeded()
        applyAccount(accountStore.currentWalletState())
        Task { [weak self] in await self?.loadMarketIfNeeded() }
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
        state.autoClose
    }

    var limitPrice: Double? {
        state.limitPrice
    }

    var context: PerpsOpenMarketContext? {
        state.context
    }

    var warningText: String? {
        state.autoCloseWarningText ?? state.reviewWarningText
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
              marginUsd(in: state) > 0,
              effectivePrice(in: state) > 0,
              meetsMinimumSize(in: state)
        else {
            return false
        }
        if state.orderType == .limit, !(state.limitPrice ?? 0 > 0) { return false }
        if case .ready = state.account { return true }
        return false
    }

    /// The planner's number for a leverage the draft has not committed to, for the
    /// leverage sheet's slider. Synchronous: the inputs are already loaded.
    func reviewedLiquidation(forLeverage leverage: Double) -> Double? {
        guard let context = state.context else { return nil }
        var draft = probingDraft(state)
        draft.leverage = leverage
        return reviewedLiquidation(in: draft, context: context)
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
        return PerpsFormatting.usd(price)
    }

    var sizeText: String? {
        switch sizeMode {
        case .usd:
            return PerpsFormatting.usd(sizeUsd)
        case .token:
            let price = effectivePrice
            guard price > 0 else { return PerpsFormatting.usd(sizeUsd) }
            return PerpsFormatting.token(sizeUsd / price, symbol: context?.symbol ?? "", decimals: context?.sizeDecimals ?? 4)
        }
    }

    var leverageText: String {
        PerpsFormatting.leverage(leverage)
    }

    var balanceText: String? {
        switch account {
        case .resolving: return nil
        case let .needsDeposit(balance): return balance.map { PerpsFormatting.usd($0) }
        case let .ready(balance): return PerpsFormatting.usd(balance)
        }
    }

    var autoCloseSummary: String? {
        autoClose.flatMap(PerpsFormatting.autoCloseSummary)
    }

    // MARK: - Intent

    func setAmount(_ text: String) {
        let sanitized = PerpsDecimalInput.sanitize(text, decimals: 2)
        let isEdit = sanitized != state.amountText
        update {
            $0.amountText = sanitized
            if isEdit { $0.reviewWarningText = nil }
        }
    }

    func toggleSizeMode() {
        update { $0.sizeMode = $0.sizeMode == .usd ? .token : .usd }
    }

    func setMax() {
        guard case let .ready(balance) = state.account, balance > 0 else { return }
        update {
            $0.amountText = PerpsDecimalInput.usdText(balance)
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

    func applyAutoClose(_ value: PerpsAutoClose?) {
        guard let value, !value.isEmpty else {
            update {
                $0.autoClose = nil
                $0.autoCloseWarningText = nil
                $0.reviewWarningText = nil
            }
            return
        }
        let warning = autoCloseWarning(for: value, in: state)
        update {
            $0.autoClose = warning == nil ? value : nil
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
            side: side,
            entryPrice: effectivePrice,
            referencePrice: effectivePrice,
            leverage: state.leverage,
            liquidationPrice: state.liquidationPrice,
            priceDecimals: context.priceDecimals,
            draft: state.autoClose
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
            switch await confirmContext() {
            case let .success(context):
                update { $0.reviewWarningText = nil }
                let limit = context.intent.limitPrice
                Log.i("🪵 Perps/OpenPosition: review → confirm market=\(marketId) side=\(side) lev=\(context.intent.leverage)x \(limit.map { "limit=\($0)" } ?? "market")")
                onReview?(context)
            case let .failure(error):
                let message = PerpsTradingErrorText.message(for: error, fallback: TKLocales.Perps.Toast.openFailed)
                update { $0.reviewWarningText = message }
                requestAmountFocus()
            }
        }
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
        Log.i("🪵 Perps/OpenPosition: load start market=\(marketId) side=\(side)")

        guard let context = await service.openMarketContext(marketId: marketId, side: side) else {
            isLoadingMarket = false
            Log.w("🪵 Perps/OpenPosition: load failed market=\(marketId) → closing")
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
        Log.i("🪵 Perps/OpenPosition: ready market=\(marketId) price=\(context.displayPrice) lev=\(state.leverage)x")
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
        let intent = openIntent(in: state, context: context)
        switch await service.previewOpenMarket(intent) {
        case let .success(review):
            guard state.context == context,
                  openIntent(in: state, context: context) == intent
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

    func referencePrice(in draft: State) -> Double {
        draft.context?.displayPrice ?? 0
    }

    func effectivePrice(in draft: State) -> Double {
        if draft.orderType == .limit, let limitPrice = draft.limitPrice, limitPrice > 0 {
            return limitPrice
        }
        return referencePrice(in: draft)
    }

    func normalizedAmount(in draft: State) -> String {
        PerpsDecimalInput.normalized(draft.amountText)
    }

    func marginUsd(in draft: State) -> Double {
        guard let value = Decimal(string: normalizedAmount(in: draft), locale: Locale(identifier: "en_US_POSIX")) else { return 0 }
        return NSDecimalNumber(decimal: value).doubleValue
    }

    func baseSize(in draft: State) -> Double {
        let price = effectivePrice(in: draft)
        guard price > 0 else { return 0 }
        return marginUsd(in: draft) * draft.leverage / price
    }

    func meetsMinimumSize(in draft: State) -> Bool {
        guard let minBaseSize = draft.context?.minBaseSize, minBaseSize > 0 else { return true }
        guard effectivePrice(in: draft) > 0 else { return true }
        return baseSize(in: draft) >= minBaseSize
    }

    func reviewedLiquidation(in draft: State, context: PerpsOpenMarketContext) -> Double? {
        guard let reviewer = draftReviewer.current else { return nil }
        return reviewer.reviewOpen(openIntent(in: draft, context: context))?.liquidationPrice
    }

    /// Reloads what a review reads. Called when there is nothing loaded yet and when
    /// the planner stops answering for the current draft — a stale observation, or a
    /// size the loaded book slice no longer covers.
    static let probeMarginUsd = "1"

    func probingDraft(_ draft: State) -> State {
        guard marginUsd(in: draft) <= 0 else { return draft }
        var probe = draft
        probe.amountText = Self.probeMarginUsd
        return probe
    }

    func loadReviewerIfNeeded() {
        guard let context = state.context else { return }
        let intent = openIntent(in: probingDraft(state), context: context)
        draftReviewer.loadIfNeeded { [service] in
            do {
                return try await service.loadReviewer(for: intent).get()
            } catch {
                Log.w("🪵 Perps/OpenPosition: reviewer load failed market=\(intent.marketId) — \(error)")
                return nil
            }
        } then: { [weak self] in
            self?.refreshReviewedLiquidation()
        }
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
        accountStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.applyAccount(observer.accountStore.currentWalletState()) }
        }
    }

    func applyAccount(_ accountState: PerpsAccountStore.State) {
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
        Log.i("🪵 Perps/OpenPosition: account → \(label) market=\(marketId)")
    }

    func resetInvalidAutoCloseIfNeeded(in draft: inout State) {
        guard let autoClose = draft.autoClose,
              !autoClose.isEmpty,
              let warning = autoCloseWarning(for: autoClose, in: draft)
        else {
            return
        }
        draft.autoClose = nil
        draft.autoCloseWarningText = warning.message
    }

    func autoCloseWarning(for autoClose: PerpsAutoClose, in draft: State) -> PerpsAutoCloseValidation.Warning? {
        PerpsAutoCloseValidation.warning(
            side: side,
            referencePrice: effectivePrice(in: draft),
            liquidationPrice: draft.liquidationPrice,
            autoClose: autoClose
        )
    }

    func openIntent(in draft: State, context: PerpsOpenMarketContext) -> PerpsOpenMarketIntent {
        PerpsOpenMarketIntent(
            marketId: marketId,
            side: side,
            marginUsd: normalizedAmount(in: draft),
            leverage: draft.leverage,
            maxSlippage: context.maxSlippage,
            autoClose: draft.autoClose,
            limitPrice: draft.orderType == .limit ? draft.limitPrice : nil
        )
    }

    func update(_ body: (inout State) -> Void) {
        var next = state
        body(&next)
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
            || old.orderType != new.orderType
            || old.limitPrice != new.limitPrice
            || old.context != new.context
    }
}

extension PerpsOpenPositionViewModel: PerpsAmountFormViewModel {
    var isLoading: Bool {
        viewState == .loading
    }

    var priceText: String {
        headerPriceText
    }

    var isPriceTappable: Bool {
        isLimitOrder
    }

    var orderTypeSwitchText: String? {
        orderTypeText
    }

    var balanceRow: PerpsAmountFormBalanceRow? {
        PerpsAmountFormBalanceRow(
            balanceText: balanceText,
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

enum PerpsOrderType: Equatable {
    case market
    case limit
}

struct PerpsLeverageSheetContext {
    let marketId: Int64
    let side: PerpsTradeSide
    let bounds: PerpsLeverageBounds
    let current: Double
}

struct PerpsAutoCloseSheetContext {
    let side: PerpsTradeSide
    let entryPrice: Double
    let referencePrice: Double
    let leverage: Double
    let liquidationPrice: Double?
    let priceDecimals: Int
    let draft: PerpsAutoClose?

    func replacingReferencePrice(_ price: Double) -> PerpsAutoCloseSheetContext {
        PerpsAutoCloseSheetContext(
            side: side,
            entryPrice: entryPrice,
            referencePrice: price,
            leverage: leverage,
            liquidationPrice: liquidationPrice,
            priceDecimals: priceDecimals,
            draft: draft
        )
    }
}

import Combine
import Foundation
import KeeperCore
import TKLogging

@MainActor
final class PerpsOpenPositionStore: ObservableObject {
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

    enum MarketLoadResult {
        case alreadyLoaded
        case loaded
        case failed
    }

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
    }

    @Published private(set) var state: State

    let marketId: Int64
    let side: PerpsTradeSide

    private let service: PerpsTradingService
    private let accountStore: PerpsAccountStore
    private var hasUserAdjustedLeverage = false
    private var isLoadingMarket = false

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
        self.state = State(leverage: initialLeverage)
        observeAccount()
    }

    var coreSide: KeeperCore.PerpsTradeSide {
        side == .long ? .long : .short
    }

    var referencePrice: Double {
        referencePrice(in: state)
    }

    var effectivePrice: Double {
        effectivePrice(in: state)
    }

    var marginUsd: Double {
        marginUsd(in: state)
    }

    var sizeUsd: Double {
        sizeUsd(in: state)
    }

    var canDeposit: Bool {
        if case .needsDeposit = state.account { return true }
        return false
    }

    var isReviewEnabled: Bool {
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

    func resolveAccountIfNeeded() {
        accountStore.resolveIfNeeded()
        applyAccount(accountStore.currentWalletState())
    }

    func loadMarketIfNeeded() async -> MarketLoadResult {
        guard state.context == nil else { return .alreadyLoaded }
        guard !isLoadingMarket else { return .alreadyLoaded }
        isLoadingMarket = true
        update { $0.viewState = .loading }
        Log.i("🪵 Perps/OpenPosition: load start market=\(marketId) side=\(side)")

        guard let context = await service.openMarketContext(marketId: marketId, side: coreSide) else {
            isLoadingMarket = false
            Log.w("🪵 Perps/OpenPosition: load failed market=\(marketId) → closing")
            return .failed
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
        return .loaded
    }

    func setAmount(_ text: String) {
        update {
            $0.amountText = PerpsDecimalInput.sanitize(text)
            $0.reviewWarningText = nil
        }
    }

    func toggleSizeMode() {
        update { $0.sizeMode = $0.sizeMode == .usd ? .token : .usd }
    }

    func setMax() {
        guard case let .ready(balance) = state.account, balance > 0 else { return }
        update {
            $0.amountText = PerpsDecimalInput.inputText(from: balance)
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

        if let warning = autoCloseWarning(for: value, in: state) {
            update {
                $0.autoClose = nil
                $0.autoCloseWarningText = warning.message
                $0.reviewWarningText = nil
            }
            return
        }

        update {
            $0.autoClose = value
            $0.autoCloseWarningText = nil
            $0.reviewWarningText = nil
        }
    }

    func leverageContext() -> PerpsLeverageSheetContext? {
        guard let context = state.context else { return nil }
        return PerpsLeverageSheetContext(
            marketId: marketId,
            side: coreSide,
            bounds: context.leverageBounds,
            current: state.leverage,
            marginUsd: marginUsd,
            openingFeeRate: context.takerFee,
            markPrice: effectivePrice,
            maintenanceFraction: context.maintenanceFraction
        )
    }

    func setLimitPriceContext() -> PerpsSetLimitPriceContext? {
        guard let context = state.context else { return nil }
        return PerpsSetLimitPriceContext(
            marketId: marketId,
            side: side,
            priceDecimals: context.priceDecimals,
            referencePrice: referencePrice,
            initialLimitPrice: state.limitPrice
        )
    }

    func autoCloseContext() -> PerpsAutoCloseSheetContext? {
        guard state.context != nil else { return nil }
        return PerpsAutoCloseSheetContext(
            side: coreSide,
            entryPrice: effectivePrice,
            leverage: state.leverage,
            liquidationPrice: estimatedLiquidationPrice,
            draft: state.autoClose
        )
    }

    func setReviewWarning(_ text: String?) {
        update { $0.reviewWarningText = text }
    }

    func confirmContext() async -> Result<PerpsConfirmContext, PerpsTradingError> {
        guard isReviewEnabled, let context = state.context else {
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
                review: review
            ))
        case let .failure(error):
            return .failure(error)
        }
    }
}

private extension PerpsOpenPositionStore {
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

    func sizeUsd(in draft: State) -> Double {
        marginUsd(in: draft) * draft.leverage
    }

    func baseSize(in draft: State) -> Double {
        let price = effectivePrice(in: draft)
        guard price > 0 else { return 0 }
        return sizeUsd(in: draft) / price
    }

    func meetsMinimumSize(in draft: State) -> Bool {
        guard let minBaseSize = draft.context?.minBaseSize, minBaseSize > 0 else { return true }
        guard effectivePrice(in: draft) > 0 else { return true }
        return baseSize(in: draft) >= minBaseSize
    }

    var estimatedLiquidationPrice: Double? {
        estimatedLiquidationPrice(in: state)
    }

    func estimatedLiquidationPrice(in draft: State) -> Double? {
        let price = effectivePrice(in: draft)
        guard let context = draft.context, let maintenanceFraction = context.maintenanceFraction, price > 0 else {
            return nil
        }
        let margin = marginUsd(in: draft) > 0 ? marginUsd(in: draft) : 1
        return service.previewLiquidation(
            side: coreSide,
            marginUsd: margin,
            leverage: draft.leverage,
            openingFeeRate: context.takerFee,
            entryPrice: price,
            markPrice: price,
            maintenanceFraction: maintenanceFraction
        ).price
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
        case .unresolved, .resolving, .activating:
            newValue = .resolving
            label = "resolving"
        case .inactive:
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
            side: coreSide,
            entryPrice: effectivePrice(in: draft),
            liquidationPrice: estimatedLiquidationPrice(in: draft),
            autoClose: autoClose
        )
    }

    func openIntent(in draft: State, context: PerpsOpenMarketContext) -> PerpsOpenMarketIntent {
        let limit = draft.orderType == .limit ? draft.limitPrice : nil
        return PerpsOpenMarketIntent(
            marketId: marketId,
            side: coreSide,
            marginUsd: normalizedAmount(in: draft),
            leverage: draft.leverage,
            maxSlippage: context.maxSlippage,
            autoClose: draft.autoClose,
            limitPrice: limit
        )
    }

    func update(_ body: (inout State) -> Void) {
        var next = state
        body(&next)
        guard next != state else { return }
        state = next
    }
}

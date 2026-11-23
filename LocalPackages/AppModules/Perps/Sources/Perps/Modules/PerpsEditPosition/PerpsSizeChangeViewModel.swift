import Combine
import Foundation
import PerpsModels
import TKLocalize
import UIKit

@MainActor
final class PerpsSizeChangeViewModel: ObservableObject, PerpsAmountFormViewModel {
    enum SizeDisplayMode: Equatable {
        case usd
        case token
    }

    @Published private(set) var amountFocusState: PerpsAmountFocusState = .active(version: 0)
    @Published private(set) var sizeMode: SizeDisplayMode = .usd
    @Published private(set) var availableBalance: Double?
    @Published private(set) var livePrice: Double?
    @Published private(set) var limits: PerpsSizeChangeLimits?

    let marketId: Int64
    let direction: PerpsSizeChangeDirection

    var onClose: (() -> Void)?
    var onDeposit: (() -> Void)?
    var onReview: (() -> Void)?
    var onOpenAutoClose: ((PerpsAutoCloseSheetContext) -> Void)?

    let session: PerpsSizeChangeSession
    private let summary: PerpsPositionSummary
    private let displayPrice: Double
    private let sizeDecimals: Int
    private let accountStore: any PerpsAccountStoring
    private let priceFeed: PerpsMarketPriceFeed
    private let loadLimits: @Sendable () async -> PerpsSizeChangeLimits?
    private var limitsTask: Task<Void, Never>?
    private var didAppear = false
    private var sessionCancellable: AnyCancellable?

    private let format: PerpsFormatting

    init(
        session: PerpsSizeChangeSession,
        summary: PerpsPositionSummary,
        displayPrice: Double,
        sizeDecimals: Int,
        accountStore: any PerpsAccountStoring,
        marketsStore: any PerpsMarketsStoring,
        loadLimits: @escaping @Sendable () async -> PerpsSizeChangeLimits?,
        format: PerpsFormatting
    ) {
        self.format = format
        self.session = session
        self.marketId = summary.marketId
        self.direction = session.direction
        self.summary = summary
        self.displayPrice = displayPrice
        self.sizeDecimals = sizeDecimals
        self.accountStore = accountStore
        self.loadLimits = loadLimits
        priceFeed = PerpsMarketPriceFeed(marketId: summary.marketId, store: marketsStore)
        sessionCancellable = session.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
        observeStore()
    }

    // MARK: - PerpsAmountFormViewModel

    var amountText: String {
        session.amountText
    }

    var isLoading: Bool {
        session.phase == .preparing
    }

    var titleText: String {
        Self.titleText(direction: direction, side: summary.side, symbol: summary.symbol)
    }

    nonisolated static func titleText(direction: PerpsSizeChangeDirection, side: PerpsTradeSide, symbol: String) -> String {
        switch (direction, side) {
        case (.add, .long): TKLocales.Perps.EditPosition.addTitleLong(symbol)
        case (.add, .short): TKLocales.Perps.EditPosition.addTitleShort(symbol)
        case (.reduce, .long): TKLocales.Perps.EditPosition.reduceTitleLong(symbol)
        case (.reduce, .short): TKLocales.Perps.EditPosition.reduceTitleShort(symbol)
        }
    }

    var priceText: String {
        guard currentPrice > 0 else { return "—" }
        return format.price(currentPrice)
    }

    var isPriceTappable: Bool {
        false
    }

    var orderTypeSwitchText: String? {
        nil
    }

    var sizeText: String? {
        let hidden = format.hiddenBalanceText
        let deltaUsd = sizeDeltaUsd
        switch sizeMode {
        case .usd:
            let oldText = format.balance(summary.notionalUsd)
            guard deltaUsd > 0 else { return oldText }
            return "\(oldText) → \(format.balance(newValue(old: summary.notionalUsd, delta: deltaUsd)))"
        case .token:
            guard currentPrice > 0 else { return format.balance(summary.notionalUsd) }
            let oldText = hidden ?? format.token(summary.baseSize, symbol: summary.symbol, decimals: sizeDecimals)
            let deltaBase = baseDelta
            guard deltaBase > 0 else { return oldText }
            let newBase = newValue(old: summary.baseSize, delta: deltaBase)
            return "\(oldText) → \(hidden ?? format.token(newBase, symbol: summary.symbol, decimals: sizeDecimals))"
        }
    }

    var balanceRow: PerpsAmountFormBalanceRow? {
        guard direction == .add else {
            return PerpsAmountFormBalanceRow(balanceText: format.balance(summary.marginUsd), onMax: nil)
        }
        return PerpsAmountFormBalanceRow(
            balanceText: availableBalance.map { format.balance($0) },
            errorText: amountIssueText,
            onMax: { [weak self] in self?.setMax() },
            onDeposit: { [weak self] in self?.onDeposit?() }
        )
    }

    var optionRows: [PerpsAmountFormOptionRow] {
        let autoCloseText = effectiveAutoClose.flatMap { format.autoCloseSummary($0) }
        return [
            summary.leverage.map {
                PerpsAmountFormOptionRow(
                    id: "leverage",
                    title: TKLocales.Perps.OpenPosition.leverage,
                    value: format.leverage($0),
                    valueColor: .textPrimary,
                    action: nil
                )
            },
            PerpsAmountFormOptionRow(
                id: "autoClose",
                title: TKLocales.Perps.OpenPosition.autoClose,
                value: autoCloseText ?? TKLocales.Perps.OpenPosition.set,
                valueColor: !canEditAutoClose ? .textTertiary : autoCloseText == nil ? .textAccent : .textPrimary,
                action: canEditAutoClose ? { [weak self] in self?.openAutoClose() } : nil
            ),
        ].compactMap { $0 }
    }

    private var canEditAutoClose: Bool {
        accountStore.marketExtras(marketId: marketId)?.flags.canEditAutoClose ?? true
    }

    var warningText: String? {
        if direction == .reduce, let amountIssueText {
            return amountIssueText
        }
        return session.reviewWarningText
    }

    var isReviewEnabled: Bool {
        guard marginDeltaUsd > 0, amountIssueText == nil else { return false }
        switch direction {
        case .add: return isAccountReady
        case .reduce: return true
        }
    }

    func onAppear() {
        accountStore.resolveIfNeeded()
        accountStore.loadMarketExtras(marketId: marketId)
        priceFeed.subscribe()
        applyStoreState()
        applyLivePrice()
        reloadLimits()
    }

    func onDisappear() {
        priceFeed.unsubscribe()
    }

    func requestFocusOnAppear() {
        didAppear = true
        requestAmountFocus()
    }

    func requestAmountFocus() {
        amountFocusState = amountFocusState.activated(requestFocus: didAppear)
    }

    func suppressAmountFocus() {
        amountFocusState = amountFocusState.suppressingFocus()
    }

    func setAmount(_ text: String) {
        session.setAmount(text)
    }

    func toggleSizeMode() {
        sizeMode = sizeMode == .usd ? .token : .usd
    }

    func review() {
        guard isReviewEnabled else { return }
        suppressAmountFocus()
        onReview?()
    }

    func openAutoClose() {
        let baseSize = newValue(old: summary.baseSize, delta: baseDelta)
        onOpenAutoClose?(PerpsAutoCloseSheetContext(
            marketId: marketId,
            side: summary.side,
            entryPrice: autoCloseBase.entryPrice,
            referencePrice: currentPrice,
            leverage: summary.effectiveLeverage ?? 0,
            baseSize: baseSize,
            liquidationPrice: summary.liquidationPrice > 0 ? summary.liquidationPrice : nil,
            priceDecimals: session.priceDecimals,
            draft: effectiveAutoClose,
            roiInput: session.autoCloseROIInput,
            livePriceMarketId: marketId
        ))
    }

    func applyAutoClose(_ value: PerpsAutoClose?, roiInput: PerpsAutoCloseROIInput? = nil) {
        guard let value, !value.isEmpty else {
            session.selectAutoClose(nil)
            return
        }
        guard PerpsAutoCloseValidation.warning(
            side: summary.side,
            referencePrice: currentPrice,
            liquidationPrice: summary.liquidationPrice > 0 ? summary.liquidationPrice : nil,
            autoClose: value,
            format: format
        ) == nil else { return }
        session.selectAutoClose(value, roiInput: roiInput)
    }

    func resolveAutoClose() {
        session.resolveAutoClose(on: autoCloseBase)
    }

    func close() {
        onClose?()
    }

    // MARK: - Private

    private var isAccountReady: Bool {
        (availableBalance ?? 0) > 0
    }

    private var currentPrice: Double {
        livePrice ?? displayPrice
    }

    private var marginDeltaUsd: Double {
        PerpsDecimalInput.double(amountText) ?? 0
    }

    private var closesWholePosition: Bool {
        direction == .reduce && PerpsSizeChangeIntent.closesWholePosition(
            marginDeltaUsd: marginDeltaUsd,
            positionMarginUsd: summary.marginUsd
        )
    }

    private var sizeDeltaUsd: Double {
        if direction == .reduce {
            return summary.baseSize > 0 ? summary.notionalUsd * baseDelta / summary.baseSize : 0
        }
        return marginDeltaUsd * (summary.effectiveLeverage ?? 0)
    }

    private var baseDelta: Double {
        var delta: Decimal
        switch direction {
        case .add:
            guard currentPrice > 0 else { return 0 }
            delta = Decimal(marginDeltaUsd) * Decimal(summary.effectiveLeverage ?? 0) / Decimal(currentPrice)
        case .reduce:
            if closesWholePosition { return summary.baseSize }
            guard summary.marginUsd > 0 else { return 0 }
            delta = Decimal(summary.baseSize) * Decimal(marginDeltaUsd) / Decimal(summary.marginUsd)
        }
        guard sizeDecimals >= 0 else { return NSDecimalNumber(decimal: delta).doubleValue }
        var stepped = Decimal()
        NSDecimalRound(&stepped, &delta, sizeDecimals, .down)
        return NSDecimalNumber(decimal: stepped).doubleValue
    }

    private var amountIssueText: String? {
        switch direction {
        case .add:
            guard marginDeltaUsd > 0 else { return nil }
            if let availableBalance, marginDeltaUsd > availableBalance {
                return TKLocales.Perps.OpenPosition.insufficientFunds
            }
            if let maxAddUsd = limits?.maxAddUsd, marginDeltaUsd > maxAddUsd {
                return TKLocales.Perps.EditPosition.maximumMargin(format.balance(maxAddUsd))
            }
            return nil
        case .reduce:
            if allowsOnlyFullClose {
                return TKLocales.Perps.EditPosition.reduceOnlyFull
            }
            guard marginDeltaUsd > 0, !closesWholePosition else { return nil }
            if marginDeltaUsd >= summary.marginUsd {
                return TKLocales.Perps.EditPosition.reduceExceedsMargin(format.balance(summary.marginUsd))
            }
            if let minReduceUsd = limits?.minReduceUsd, marginDeltaUsd < minReduceUsd {
                return TKLocales.Perps.OpenPosition.minimumMargin(format.usd(minReduceUsd))
            }
            if let maxReduceUsd = limits?.maxReduceUsd, marginDeltaUsd > maxReduceUsd {
                return TKLocales.Perps.EditPosition.reduceExceedsMargin(format.balance(maxReduceUsd))
            }
            return nil
        }
    }

    private var allowsOnlyFullClose: Bool {
        guard let limits else { return false }
        guard let minReduceUsd = limits.minReduceUsd else { return true }
        if let maxReduceUsd = limits.maxReduceUsd, minReduceUsd > maxReduceUsd { return true }
        return minReduceUsd >= summary.marginUsd
    }

    private func newValue(old: Double, delta: Double) -> Double {
        direction == .add ? old + delta : max(0, old - delta)
    }

    private var effectiveAutoClose: PerpsAutoClose? {
        session.autoCloseROIInput.resolving(session.desiredAutoClose, on: autoCloseBase)
    }

    private var autoCloseBase: PerpsAutoCloseBase {
        let baseSize = newValue(old: summary.baseSize, delta: baseDelta)
        let entryPrice = direction == .add && baseSize > 0
            ? (summary.baseSize * summary.entryPrice + baseDelta * currentPrice) / baseSize
            : summary.entryPrice
        return PerpsAutoCloseBase(
            side: summary.side,
            entryPrice: entryPrice,
            leverage: summary.effectiveLeverage ?? 0,
            priceDecimals: session.priceDecimals
        )
    }

    private func setMax() {
        guard let availableBalance, availableBalance > 0 else { return }
        session.setAmount(PerpsDecimalInput.usdText(min(availableBalance, limits?.maxAddUsd ?? availableBalance)))
    }

    private func reloadLimits() {
        limitsTask?.cancel()
        limitsTask = Task { [weak self, loadLimits] in
            let limits = await loadLimits()
            guard !Task.isCancelled, let self, let limits else { return }
            self.limits = limits
        }
    }

    private func observeStore() {
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.applyStoreState() }
        }
        priceFeed.observe(self) { $0.applyLivePrice() }
    }

    private func applyLivePrice() {
        guard let price = priceFeed.livePrice, price != livePrice else { return }
        livePrice = price
    }

    private func applyStoreState() {
        let balance: Double?
        switch accountStore.currentWalletState() {
        case .unresolved, .resolving, .unbound, .inactive:
            balance = nil
        case let .active(value):
            balance = PerpsMarketMath.optionalDouble(value.availableBalance) ?? 0
        }
        if balance != availableBalance {
            availableBalance = balance
            if limitsTask != nil {
                reloadLimits()
            }
        }
        let orders = accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        session.updateRestingTriggerOrders(orders)
    }
}

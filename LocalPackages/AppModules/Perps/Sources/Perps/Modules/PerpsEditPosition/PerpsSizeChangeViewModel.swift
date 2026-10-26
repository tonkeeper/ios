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

    let marketId: Int64
    let direction: PerpsSizeChangeDirection

    var onClose: (() -> Void)?
    var onDeposit: (() -> Void)?
    var onReview: (() -> Void)?
    var onOpenAutoClose: ((PerpsAutoCloseSheetContext) -> Void)?

    private let session: PerpsSizeChangeSession
    private let summary: PerpsPositionSummary
    private let displayPrice: Double
    private let sizeDecimals: Int
    private let accountStore: any PerpsAccountStoring
    private let priceFeed: PerpsMarketPriceFeed
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

    var restingTriggerOrders: [PerpsTriggerOrderSummary] {
        session.restingTriggerOrders
    }

    var intent: PerpsSizeChangeIntent {
        session.intent
    }

    var isLoading: Bool {
        session.phase == .preparing
    }

    var titleText: String {
        let sideText = summary.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short
        let position = "\(sideText) \(summary.symbol)"
        switch direction {
        case .add: return TKLocales.Perps.EditPosition.addTitle(position)
        case .reduce: return TKLocales.Perps.EditPosition.reduceTitle(position)
        }
    }

    var priceText: String {
        guard currentPrice > 0 else { return "—" }
        return format.usd(currentPrice)
    }

    var isPriceTappable: Bool {
        false
    }

    var orderTypeSwitchText: String? {
        nil
    }

    var sizeText: String? {
        let deltaUsd = sizeDeltaUsd
        switch sizeMode {
        case .usd:
            guard deltaUsd > 0 else { return format.usd(summary.notionalUsd) }
            return "\(format.usd(summary.notionalUsd)) → \(format.usd(newValue(old: summary.notionalUsd, delta: deltaUsd)))"
        case .token:
            guard currentPrice > 0 else { return format.usd(summary.notionalUsd) }
            let oldText = format.token(summary.baseSize, symbol: summary.symbol, decimals: sizeDecimals)
            let deltaBase = baseDelta
            guard deltaBase > 0 else { return oldText }
            let newBase = newValue(old: summary.baseSize, delta: deltaBase)
            return "\(oldText) → \(format.token(newBase, symbol: summary.symbol, decimals: sizeDecimals))"
        }
    }

    var balanceRow: PerpsAmountFormBalanceRow? {
        guard direction == .add else { return nil }
        return PerpsAmountFormBalanceRow(
            balanceText: availableBalance.map { format.usd($0) },
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
                valueColor: autoCloseText == nil ? .textAccent : .textPrimary,
                action: { [weak self] in self?.openAutoClose() }
            ),
        ].compactMap { $0 }
    }

    var warningText: String? {
        if exceedsReduceMargin {
            return TKLocales.Perps.EditPosition.reduceExceedsMargin(format.usd(summary.marginUsd))
        }
        return session.reviewWarningText
    }

    var isReviewEnabled: Bool {
        guard marginDeltaUsd > 0 else { return false }
        switch direction {
        case .add: return isAccountReady
        case .reduce: return !exceedsReduceMargin
        }
    }

    func onAppear() {
        accountStore.resolveIfNeeded()
        accountStore.loadMarketExtras(marketId: marketId)
        priceFeed.subscribe()
        applyStoreState()
        applyLivePrice()
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

    private var sizeDeltaUsd: Double {
        if direction == .reduce {
            return summary.marginUsd > 0 ? summary.notionalUsd * marginDeltaUsd / summary.marginUsd : 0
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
            guard summary.marginUsd > 0 else { return 0 }
            delta = Decimal(summary.baseSize) * Decimal(marginDeltaUsd) / Decimal(summary.marginUsd)
        }
        guard sizeDecimals >= 0 else { return NSDecimalNumber(decimal: delta).doubleValue }
        var stepped = Decimal()
        NSDecimalRound(&stepped, &delta, sizeDecimals, .down)
        return NSDecimalNumber(decimal: stepped).doubleValue
    }

    private var exceedsReduceMargin: Bool {
        direction == .reduce && marginDeltaUsd > 0 && marginDeltaUsd >= summary.marginUsd
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
        session.setAmount(PerpsDecimalInput.usdText(availableBalance))
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
        switch accountStore.currentWalletState() {
        case .unresolved, .resolving, .unbound, .inactive:
            availableBalance = nil
        case let .active(value):
            availableBalance = PerpsMarketMath.optionalDouble(value.availableBalance) ?? 0
        }
        let orders = accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        session.updateRestingTriggerOrders(orders)
    }
}

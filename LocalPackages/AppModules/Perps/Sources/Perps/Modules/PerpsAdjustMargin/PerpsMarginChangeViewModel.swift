import Foundation
import PerpsModels
import TKLocalize
import UIKit

@MainActor
final class PerpsMarginChangeViewModel: ObservableObject, PerpsAmountFormViewModel {
    private let draftReviewer = PerpsDraftReviewer()

    @Published private(set) var amountFocusState: PerpsAmountFocusState = .active(version: 0)
    @Published private(set) var amountText: String = ""
    @Published private(set) var availableBalance: Double?
    @Published private(set) var reviewWarningText: String?
    /// Last liquidation the planner reviewed for the typed amount; the client
    /// derives no trade figures of its own.
    @Published private(set) var projectedLiquidation: PerpsValueChange?
    @Published private(set) var isImmediateRisk = false
    @Published private(set) var livePrice: Double?
    @Published private(set) var limits: PerpsMarginChangeLimits?

    let marketId: Int64
    let direction: PerpsMarginChangeDirection

    var onClose: (() -> Void)?
    var onDeposit: (() -> Void)?
    var onReview: ((PerpsMarginChangeIntent) -> Void)?

    private let summary: PerpsPositionSummary
    private let displayPrice: Double
    private let accountStore: any PerpsAccountStoring
    private let priceFeed: PerpsMarketPriceFeed
    private let tradingService: PerpsTradingService
    private var didAppear = false
    private var limitsTask: Task<Void, Never>?

    private let format: PerpsFormatting

    init(
        direction: PerpsMarginChangeDirection,
        summary: PerpsPositionSummary,
        displayPrice: Double,
        accountStore: any PerpsAccountStoring,
        marketsStore: any PerpsMarketsStoring,
        tradingService: PerpsTradingService,
        format: PerpsFormatting
    ) {
        self.format = format
        self.marketId = summary.marketId
        self.direction = direction
        self.summary = summary
        self.displayPrice = displayPrice
        self.accountStore = accountStore
        priceFeed = PerpsMarketPriceFeed(marketId: summary.marketId, store: marketsStore)
        self.tradingService = tradingService
        observeStore()
    }

    // MARK: - PerpsAmountFormViewModel

    var isLoading: Bool {
        false
    }

    var titleText: String {
        switch direction {
        case .add: return TKLocales.Perps.AdjustMargin.add
        case .reduce: return TKLocales.Perps.AdjustMargin.reduce
        }
    }

    var priceText: String {
        let price = livePrice ?? displayPrice
        guard price > 0 else { return "—" }
        return format.usd(price)
    }

    var isPriceTappable: Bool {
        false
    }

    var orderTypeSwitchText: String? {
        nil
    }

    var sizeText: String? {
        nil
    }

    var balanceRow: PerpsAmountFormBalanceRow? {
        switch direction {
        case .add:
            return PerpsAmountFormBalanceRow(
                balanceText: availableBalance.map { format.usd($0) },
                errorText: amountIssueText,
                onMax: { [weak self] in self?.setMax() },
                onDeposit: { [weak self] in self?.onDeposit?() }
            )
        case .reduce:
            return PerpsAmountFormBalanceRow(
                balanceText: limits.map { format.usd($0.maxReduceUsd) },
                errorText: amountIssueText,
                onMax: { [weak self] in self?.setMax() }
            )
        }
    }

    var optionRows: [PerpsAmountFormOptionRow] {
        [PerpsAmountFormOptionRow(
            id: "liquidation",
            title: TKLocales.Perps.Confirm.liquidation,
            value: liquidationRowValue,
            valueColor: .textPrimary,
            action: nil
        )]
    }

    var warningText: String? {
        if exceedsReduceMargin {
            return TKLocales.Perps.EditPosition.reduceExceedsMargin(format.usd(summary.marginUsd))
        }
        if isReduceAtImmediateRisk {
            return TKLocales.Perps.AdjustMargin.reduceRisk
        }
        return reviewWarningText
    }

    var isReviewEnabled: Bool {
        guard isAmountReviewable else { return false }
        switch direction {
        case .add: return isAccountReady
        case .reduce: return !isReduceAtImmediateRisk
        }
    }

    func onAppear() {
        accountStore.resolveIfNeeded()
        priceFeed.subscribe()
        applyStoreState()
        applyLivePrice()
        loadLimits()
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
        let sanitized = PerpsDecimalInput.sanitize(text, decimals: 2)
        let isEdit = sanitized != amountText
        amountText = sanitized
        refreshProjectedLiquidation()
        if isEdit { reviewWarningText = nil }
    }

    func toggleSizeMode() {}

    func review() {
        guard isReviewEnabled else { return }
        suppressAmountFocus()
        onReview?(PerpsMarginChangeIntent(
            marketId: marketId,
            direction: direction,
            amountUsd: PerpsDecimalInput.normalized(amountText)
        ))
    }

    func reviewFailed(warning: String?) {
        if let warning { reviewWarningText = warning }
        requestAmountFocus()
    }

    func close() {
        onClose?()
    }

    // MARK: - Private

    private var isAccountReady: Bool {
        (availableBalance ?? 0) > 0
    }

    private var amountUsd: Double {
        PerpsDecimalInput.double(amountText) ?? 0
    }

    private var isAmountReviewable: Bool {
        amountUsd > 0 && amountIssueText == nil && !exceedsReduceMargin
    }

    private var amountIssueText: String? {
        guard amountUsd > 0, let limits else { return nil }
        if amountUsd < limits.minUsd {
            return TKLocales.Perps.AdjustMargin.minAmount(format.usd(limits.minUsd))
        }
        guard direction == .reduce, amountUsd > limits.maxReduceUsd else { return nil }
        return TKLocales.Perps.AdjustMargin.maxReduce(format.usd(limits.maxReduceUsd))
    }

    private var exceedsReduceMargin: Bool {
        limits == nil && direction == .reduce && amountUsd > 0 && amountUsd >= summary.marginUsd
    }

    private var isReduceAtImmediateRisk: Bool {
        direction == .reduce && isImmediateRisk
    }

    private var liquidationRowValue: String {
        let oldText = summary.liquidationPrice > 0 ? format.usd(summary.liquidationPrice) : "—"
        guard let projected = projectedLiquidation?.new else { return oldText }
        return "\(oldText) → \(format.usd(projected))"
    }

    private func refreshProjectedLiquidation() {
        guard isAmountReviewable, let reviewer = draftReviewer.current else {
            projectedLiquidation = nil
            isImmediateRisk = false
            loadReviewerIfNeeded()
            return
        }
        let intent = PerpsMarginChangeIntent(
            marketId: marketId,
            direction: direction,
            amountUsd: PerpsDecimalInput.normalized(amountText)
        )
        guard let review = reviewer.reviewMarginChange(intent) else {
            projectedLiquidation = nil
            isImmediateRisk = false
            loadReviewerIfNeeded()
            return
        }
        projectedLiquidation = review.liquidationPrice
        isImmediateRisk = review.isImmediateRisk
        if draftReviewer.needsLoad {
            loadReviewerIfNeeded()
        }
    }

    private func loadReviewerIfNeeded() {
        guard isAmountReviewable else { return }
        let intent = PerpsMarginChangeIntent(
            marketId: marketId,
            direction: direction,
            amountUsd: PerpsDecimalInput.normalized(amountText)
        )
        draftReviewer.loadIfNeeded { [tradingService] in
            try? await tradingService.loadReviewer(for: intent).get()
        } then: { [weak self] in
            self?.refreshProjectedLiquidation()
        }
    }

    private func setMax() {
        let max = direction == .add ? availableBalance : limits?.maxReduceUsd
        guard let max, max > 0 else { return }
        amountText = PerpsDecimalInput.usdText(max)
        reviewWarningText = nil
        refreshProjectedLiquidation()
    }

    private func loadLimits() {
        limitsTask?.cancel()
        limitsTask = Task { [weak self, tradingService, marketId] in
            let result = await tradingService.marginChangeLimits(marketId: marketId)
            guard !Task.isCancelled, let self, case let .success(limits) = result else { return }
            self.limits = limits
            refreshProjectedLiquidation()
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
        switch accountStore.currentWalletState() {
        case .unresolved, .resolving, .unbound, .inactive:
            availableBalance = nil
        case let .active(value):
            availableBalance = PerpsMarketMath.optionalDouble(value.availableBalance) ?? 0
        }
    }
}

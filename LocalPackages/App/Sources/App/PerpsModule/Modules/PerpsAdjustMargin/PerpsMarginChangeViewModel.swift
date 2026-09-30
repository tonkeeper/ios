import Foundation
import KeeperCore
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

    let marketId: Int64
    let direction: PerpsMarginChangeDirection

    var onClose: (() -> Void)?
    var onDeposit: (() -> Void)?
    var onReview: ((PerpsMarginChangeIntent) -> Void)?

    private let summary: PerpsPositionSummary
    private let displayPrice: Double
    private let accountStore: PerpsAccountStore
    private let tradingService: PerpsTradingService
    private var didAppear = false

    init(
        direction: PerpsMarginChangeDirection,
        summary: PerpsPositionSummary,
        displayPrice: Double,
        accountStore: PerpsAccountStore,
        tradingService: PerpsTradingService
    ) {
        self.marketId = summary.marketId
        self.direction = direction
        self.summary = summary
        self.displayPrice = displayPrice
        self.accountStore = accountStore
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
        guard displayPrice > 0 else { return "—" }
        return PerpsFormatting.usd(displayPrice)
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
        guard direction == .add else { return nil }
        return PerpsAmountFormBalanceRow(
            balanceText: availableBalance.map { PerpsFormatting.usd($0) },
            onMax: { [weak self] in self?.setMax() },
            onDeposit: { [weak self] in self?.onDeposit?() }
        )
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
            return TKLocales.Perps.EditPosition.reduceExceedsMargin(PerpsFormatting.usd(summary.marginUsd))
        }
        if isReduceAtImmediateRisk {
            return TKLocales.Perps.AdjustMargin.reduceRisk
        }
        return reviewWarningText
    }

    var isReviewEnabled: Bool {
        guard amountUsd > 0 else { return false }
        switch direction {
        case .add: return isAccountReady
        case .reduce: return !exceedsReduceMargin && !isReduceAtImmediateRisk
        }
    }

    func onAppear() {
        accountStore.resolveIfNeeded()
        applyStoreState()
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

    func setReviewWarning(_ text: String?) {
        reviewWarningText = text
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

    private var exceedsReduceMargin: Bool {
        direction == .reduce && amountUsd > 0 && amountUsd >= summary.marginUsd
    }

    private var isReduceAtImmediateRisk: Bool {
        direction == .reduce && isImmediateRisk
    }

    private var liquidationRowValue: String {
        let oldText = summary.liquidationPrice > 0 ? PerpsFormatting.usd(summary.liquidationPrice) : "—"
        guard let projected = projectedLiquidation?.new else { return oldText }
        return "\(oldText) → \(PerpsFormatting.usd(projected))"
    }

    private func refreshProjectedLiquidation() {
        guard amountUsd > 0, let reviewer = draftReviewer.current else {
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
        guard amountUsd > 0 else { return }
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
        guard let availableBalance, availableBalance > 0 else { return }
        amountText = PerpsDecimalInput.usdText(availableBalance)
        reviewWarningText = nil
        refreshProjectedLiquidation()
    }

    private func observeStore() {
        accountStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.applyStoreState() }
        }
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

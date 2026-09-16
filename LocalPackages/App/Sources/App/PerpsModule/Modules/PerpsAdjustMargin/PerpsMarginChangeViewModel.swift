import Foundation
import KeeperCore
import TKLocalize
import UIKit

@MainActor
final class PerpsMarginChangeViewModel: ObservableObject, PerpsAmountFormViewModel {
    @Published private(set) var amountFocusState: PerpsAmountFocusState = .active(version: 0)
    @Published private(set) var amountText: String = ""
    @Published private(set) var availableBalance: Double?
    @Published private(set) var reviewWarningText: String?
    @Published private(set) var maintenanceFraction: Double?

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
    private var didLoadContext = false

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
        loadContextIfNeeded()
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
        amountText = PerpsDecimalInput.sanitize(text)
        reviewWarningText = nil
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
        direction == .reduce && projectedLiquidation?.isImmediateRisk == true
    }

    private var liquidationRowValue: String {
        let oldText = summary.liquidationPrice > 0 ? PerpsFormatting.usd(summary.liquidationPrice) : "—"
        guard let projected = projectedLiquidation?.price else { return oldText }
        return "\(oldText) → \(PerpsFormatting.usd(projected))"
    }

    private var projectedLiquidation: PerpsLiquidationPreview? {
        guard amountUsd > 0, let maintenanceFraction, displayPrice > 0 else { return nil }
        let collateral = direction == .add
            ? summary.marginUsd + amountUsd
            : summary.marginUsd - amountUsd
        guard collateral > 0 else { return nil }
        return tradingService.previewPositionLiquidation(
            side: summary.side,
            baseSize: summary.baseSize,
            entryPrice: summary.entryPrice,
            markPrice: displayPrice,
            maintenanceFraction: maintenanceFraction,
            collateralUsd: collateral
        )
    }

    private func setMax() {
        guard let availableBalance, availableBalance > 0 else { return }
        amountText = PerpsDecimalInput.inputText(from: availableBalance)
        reviewWarningText = nil
    }

    private func loadContextIfNeeded() {
        guard !didLoadContext else { return }
        didLoadContext = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let context = await tradingService.openMarketContext(marketId: marketId, side: summary.side)
            maintenanceFraction = context?.maintenanceFraction
        }
    }

    private func observeStore() {
        accountStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.applyStoreState() }
        }
    }

    private func applyStoreState() {
        switch accountStore.currentWalletState() {
        case .unresolved, .resolving, .activating, .inactive:
            availableBalance = nil
        case let .active(value):
            availableBalance = PerpsMarketMath.optionalDouble(value.availableBalance) ?? 0
        }
    }
}

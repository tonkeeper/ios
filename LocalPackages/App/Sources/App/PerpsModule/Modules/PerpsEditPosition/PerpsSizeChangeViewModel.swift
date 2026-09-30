import Combine
import Foundation
import KeeperCore
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
    private let accountStore: PerpsAccountStore
    private var didAppear = false
    private var sessionCancellable: AnyCancellable?

    init(
        session: PerpsSizeChangeSession,
        summary: PerpsPositionSummary,
        displayPrice: Double,
        sizeDecimals: Int,
        accountStore: PerpsAccountStore
    ) {
        self.session = session
        self.marketId = summary.marketId
        self.direction = session.direction
        self.summary = summary
        self.displayPrice = displayPrice
        self.sizeDecimals = sizeDecimals
        self.accountStore = accountStore
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
        let deltaUsd = sizeDeltaUsd
        switch sizeMode {
        case .usd:
            guard deltaUsd > 0 else { return PerpsFormatting.usd(summary.notionalUsd) }
            return "\(PerpsFormatting.usd(summary.notionalUsd)) → \(PerpsFormatting.usd(newValue(old: summary.notionalUsd, delta: deltaUsd)))"
        case .token:
            guard displayPrice > 0 else { return PerpsFormatting.usd(summary.notionalUsd) }
            let oldText = PerpsFormatting.token(summary.baseSize, symbol: summary.symbol, decimals: sizeDecimals)
            let deltaBase = deltaUsd / displayPrice
            guard deltaBase > 0 else { return oldText }
            let newBase = newValue(old: summary.baseSize, delta: deltaBase)
            return "\(oldText) → \(PerpsFormatting.token(newBase, symbol: summary.symbol, decimals: sizeDecimals))"
        }
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
        let autoCloseText = effectiveAutoClose.flatMap(PerpsFormatting.autoCloseSummary)
        return [
            summary.leverage.map {
                PerpsAmountFormOptionRow(
                    id: "leverage",
                    title: TKLocales.Perps.OpenPosition.leverage,
                    value: PerpsFormatting.leverage($0),
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
            return TKLocales.Perps.EditPosition.reduceExceedsMargin(PerpsFormatting.usd(summary.marginUsd))
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
        onOpenAutoClose?(PerpsAutoCloseSheetContext(
            side: summary.side,
            entryPrice: summary.entryPrice,
            referencePrice: displayPrice,
            leverage: summary.effectiveLeverage ?? 0,
            liquidationPrice: summary.liquidationPrice > 0 ? summary.liquidationPrice : nil,
            priceDecimals: session.priceDecimals,
            draft: session.desiredAutoClose
        ))
    }

    func applyAutoClose(_ value: PerpsAutoClose?) {
        guard let value, !value.isEmpty else {
            session.selectAutoClose(nil)
            return
        }
        guard PerpsAutoCloseValidation.warning(
            side: summary.side,
            referencePrice: displayPrice,
            liquidationPrice: summary.liquidationPrice > 0 ? summary.liquidationPrice : nil,
            autoClose: value
        ) == nil else { return }
        session.selectAutoClose(value)
    }

    func close() {
        onClose?()
    }

    // MARK: - Private

    private var isAccountReady: Bool {
        (availableBalance ?? 0) > 0
    }

    private var marginDeltaUsd: Double {
        PerpsDecimalInput.double(amountText) ?? 0
    }

    private var sizeDeltaUsd: Double {
        marginDeltaUsd * (summary.effectiveLeverage ?? 0)
    }

    private var exceedsReduceMargin: Bool {
        direction == .reduce && marginDeltaUsd > 0 && marginDeltaUsd >= summary.marginUsd
    }

    private func newValue(old: Double, delta: Double) -> Double {
        direction == .add ? old + delta : max(0, old - delta)
    }

    private var effectiveAutoClose: PerpsAutoClose? {
        session.desiredAutoClose
    }

    private func setMax() {
        guard let availableBalance, availableBalance > 0 else { return }
        session.setAmount(PerpsDecimalInput.usdText(availableBalance))
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
        let orders = accountStore.marketExtras(marketId: marketId)?.triggerOrders ?? []
        session.updateRestingTriggerOrders(orders)
    }
}

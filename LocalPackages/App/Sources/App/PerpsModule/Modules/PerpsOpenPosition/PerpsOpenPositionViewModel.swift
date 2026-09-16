import Combine
import Foundation
import KeeperCore
import SwiftUI
import TKLocalize
import TKLogging

@MainActor
final class PerpsOpenPositionViewModel: ObservableObject {
    @Published private(set) var amountFocusState: PerpsAmountFocusState = .active(version: 0)
    @Published private(set) var isReviewInFlight = false
    @Published private var storeState: PerpsOpenPositionStore.State

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

    private let store: PerpsOpenPositionStore
    private var didAppear = false
    private var storeCancellable: AnyCancellable?

    init(
        marketId: Int64,
        side: PerpsTradeSide,
        service: PerpsTradingService,
        accountStore: PerpsAccountStore,
        initialLeverage: Double
    ) {
        self.marketId = marketId
        self.side = side
        let store = PerpsOpenPositionStore(
            marketId: marketId,
            side: side,
            service: service,
            accountStore: accountStore,
            initialLeverage: initialLeverage
        )
        self.store = store
        self.storeState = store.state
        observeStore()
    }

    // MARK: - Lifecycle

    func onAppear() {
        store.resolveAccountIfNeeded()
        Task { [weak self] in
            guard let self else { return }
            switch await store.loadMarketIfNeeded() {
            case .alreadyLoaded:
                break
            case .loaded:
                requestAmountFocusIfActive()
            case .failed:
                onLoadFailed?()
            }
        }
    }

    func requestFocusOnAppear() {
        didAppear = true
        requestAmountFocus()
    }

    func requestAmountFocus() {
        amountFocusState = amountFocusState.activated(requestFocus: canFocusAmount)
    }

    func suppressAmountFocus() {
        amountFocusState = amountFocusState.suppressingFocus()
    }

    private var canFocusAmount: Bool {
        didAppear && viewState == .ready
    }

    private func requestAmountFocusIfActive() {
        guard amountFocusState.isActive else { return }
        requestAmountFocus()
    }

    // MARK: - Derived display

    var viewState: PerpsOpenPositionStore.ViewState {
        storeState.viewState
    }

    var account: PerpsOpenPositionStore.AccountState {
        storeState.account
    }

    var orderType: PerpsOrderType {
        storeState.orderType
    }

    var amountText: String {
        storeState.amountText
    }

    var sizeMode: PerpsOpenPositionStore.SizeDisplayMode {
        storeState.sizeMode
    }

    var leverage: Double {
        storeState.leverage
    }

    var autoClose: PerpsAutoClose? {
        storeState.autoClose
    }

    var autoCloseWarningText: String? {
        storeState.autoCloseWarningText
    }

    var warningText: String? {
        storeState.autoCloseWarningText ?? storeState.reviewWarningText
    }

    var limitPrice: Double? {
        storeState.limitPrice
    }

    var context: PerpsOpenMarketContext? {
        storeState.context
    }

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

    var effectivePrice: Double {
        store.effectivePrice
    }

    var headerPriceText: String {
        let price = effectivePrice
        guard price > 0 else { return "—" }
        return PerpsFormatting.usd(price)
    }

    var marginUsd: Double {
        store.marginUsd
    }

    var sizeUsd: Double {
        store.sizeUsd
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

    var canDeposit: Bool {
        store.canDeposit
    }

    var isReviewEnabled: Bool {
        !isReviewInFlight && store.isReviewEnabled
    }

    // MARK: - Intent

    func setAmount(_ text: String) {
        store.setAmount(text)
    }

    func toggleSizeMode() {
        store.toggleSizeMode()
    }

    func setMax() {
        store.setMax()
    }

    func openLeverage() {
        guard let context = store.leverageContext() else { return }
        onOpenLeverage?(context)
    }

    func openOrderType() {
        onOpenOrderType?(orderType)
    }

    func applyOrderType(_ type: PerpsOrderType) {
        store.applyOrderType(type)
    }

    func openSetLimitPrice() {
        guard let context = store.setLimitPriceContext() else { return }
        onOpenSetLimitPrice?(context)
    }

    func applyLimitPrice(_ price: Double) {
        store.applyLimitPrice(price)
    }

    func openAutoClose() {
        guard let context = store.autoCloseContext() else { return }
        onOpenAutoClose?(context)
    }

    func applyLeverage(_ value: Double) {
        store.applyLeverage(value)
    }

    func applyAutoClose(_ value: PerpsAutoClose?) {
        store.applyAutoClose(value)
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
            defer { self.isReviewInFlight = false }
            switch await self.store.confirmContext() {
            case let .success(context):
                self.store.setReviewWarning(nil)
                let limit = context.intent.limitPrice
                Log.i("🪵 Perps/OpenPosition: review → confirm market=\(self.marketId) side=\(self.side) lev=\(context.intent.leverage)x \(limit.map { "limit=\($0)" } ?? "market")")
                self.onReview?(context)
            case let .failure(error):
                let message = PerpsTradingErrorText.message(for: error)
                self.store.setReviewWarning(message.isEmpty ? TKLocales.Perps.Toast.openFailed : message)
            }
        }
    }

    // MARK: - Private

    private func observeStore() {
        storeCancellable = store.$state.sink { [weak self] state in
            self?.storeState = state
        }
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
    let side: KeeperCore.PerpsTradeSide
    let bounds: PerpsLeverageBounds
    let current: Double
    let marginUsd: Double
    let openingFeeRate: Double
    let markPrice: Double
    let maintenanceFraction: Double?
}

struct PerpsAutoCloseSheetContext {
    let side: KeeperCore.PerpsTradeSide
    let entryPrice: Double
    let leverage: Double
    let liquidationPrice: Double?
    let draft: PerpsAutoClose?
}

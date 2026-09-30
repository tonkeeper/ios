import Combine
import Foundation
import KeeperCore
import SwiftUI
import TKLocalize

@MainActor
final class PerpsAssetPageViewModel: ObservableObject {
    struct Position: Equatable {
        let valueText: String
        let pnlText: String
        let pnlPercentText: String?
        let isPnlPositive: Bool
        let isLong: Bool
        let sideText: String
        let leverageText: String?
        let sizeUsdText: String
        let sizeTokenText: String
        let liquidationText: String
        let liquidationDistanceText: String?
        let markText: String
        let entryText: String
        let fundingText: String
    }

    enum AutoCloseAffordance: Equatable {
        case setAutoClose
        case setTakeProfit
        case setStopLoss
        case none
    }

    struct TriggerOrder: Equatable, Identifiable {
        let id: String
        let actionText: String
        let kindText: String
        let isTakeProfit: Bool
        let priceText: String
        let valueText: String?
        let percentText: String?
        let isPositive: Bool
    }

    struct LimitOrder: Equatable, Identifiable {
        let id: String
        let orderIndex: Int64
        let actionText: String
        let priceText: String
        let valueText: String
    }

    struct ActivityRow: Equatable, Identifiable {
        let id: String
        let title: String
        let symbol: String
        let dateText: String
        let amountText: String?
        let isAmountPositive: Bool
    }

    enum Actions: Equatable {
        case longShort(enabled: Bool)
        case editCashOut(editEnabled: Bool, cashOutEnabled: Bool)
        case hidden
    }

    struct Ready: Equatable {
        let title: String
        let symbol: String
        let iconLetter: String
        let iconURL: URL?
        let priceText: String
        let changePercentText: String
        let changeAmountText: String
        let isChangePositive: Bool
        let volumeText: String
        let openInterestText: String
        let fundingText: String?
        let about: String?
        let position: Position?
        let limitOrders: [LimitOrder]
        let orders: [TriggerOrder]
        let autoClose: AutoCloseAffordance
        let history: [ActivityRow]
        let canAdjustMargin: Bool
        let canEditAutoClose: Bool
        let canCancelOrders: Bool
        let actions: Actions
    }

    enum State: Equatable {
        case loading
        case ready(Ready)
        case failed
        case notFound
    }

    enum TradeToast: Equatable {
        case progress(String)
        case success(String)
        case failure(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var tradeToast: TradeToast?
    @Published private(set) var chartMarkers: [PerpsChartPositionMarker] = []

    var onBack: (() -> Void)?
    var onMore: (() -> Void)?
    var onPerpetualInfo: (() -> Void)?
    var onTrade: ((Int64, PerpsTradeSide) -> Void)?
    var onEdit: ((Int64, Set<PerpsSizeChangeDirection>) -> Void)?
    var onCashOut: ((Int64) -> Void)?
    var onAdjustMargin: ((Int64) -> Void)?
    var onAutoClose: ((Int64) -> Void)?
    var onLimitOrder: ((Int64, PerpsLimitOrderSummary) -> Void)?
    var onShare: ((SharePositionSnapshot) -> Void)?
    var onSeeAllHistory: ((Int64) -> Void)?

    let marketId: Int64
    var priceDecimals: Int? {
        guard case let .ready(snapshot, _, _) = currentMarketInput() else { return nil }
        return snapshot.priceDecimals
    }

    private let store: PerpsMarketsStore
    private let priceInterest: PerpsMarketsPriceInterest
    private let marketDetailsStore: PerpsMarketDetailsStore
    private let accountStore: PerpsAccountStore
    private let openPositionFlow: PerpsOpenPositionFlow
    private var openPositionFlowCancellable: AnyCancellable?
    private var terminalToast: TradeToast?
    private var terminalToastTask: Task<Void, Never>?
    private var livePrice: Double?
    private var lastMarkPrice: Double?

    init(
        marketId: Int64,
        store: PerpsMarketsStore,
        marketDetailsStore: PerpsMarketDetailsStore,
        accountStore: PerpsAccountStore,
        openPositionFlow: PerpsOpenPositionFlow
    ) {
        self.marketId = marketId
        self.store = store
        priceInterest = store.makePriceInterest()
        self.marketDetailsStore = marketDetailsStore
        self.accountStore = accountStore
        self.openPositionFlow = openPositionFlow
        observeStores()
        recompute()
    }

    func onAppear() {
        priceInterest.set(marketIds: [marketId])
        marketDetailsStore.load(marketId: marketId)
        accountStore.resolveIfNeeded()
        accountStore.subscribePositions()
        accountStore.loadMarketExtras(marketId: marketId)
        applyMarketsStoreState()
    }

    func onDisappear() {
        priceInterest.clear()
        accountStore.unsubscribePositions()
        accountStore.releaseMarketExtras(marketId: marketId)
    }

    func retry() {
        marketDetailsStore.load(marketId: marketId)
        accountStore.refresh()
        accountStore.loadMarketExtras(marketId: marketId)
    }

    func long() {
        onTrade?(marketId, .long)
    }

    func short() {
        onTrade?(marketId, .short)
    }

    func edit() {
        onEdit?(marketId, Self.editDirections(
            snapshot: currentMarketInput().snapshot,
            flags: accountStore.marketExtras(marketId: marketId)?.flags,
            isAccountActive: isAccountActive
        ))
    }

    func cashOut() {
        onCashOut?(marketId)
    }

    func adjustMargin() {
        onAdjustMargin?(marketId)
    }

    func autoClose() {
        onAutoClose?(marketId)
    }

    func limitOrder(_ orderIndex: Int64) {
        guard let order = accountStore.marketExtras(marketId: marketId)?.limitOrders.first(where: {
            $0.orderIndex == orderIndex
        }) else {
            accountStore.loadMarketExtras(marketId: marketId)
            return
        }
        onLimitOrder?(marketId, order)
    }

    func share() {
        guard let snapshot = currentShareSnapshot() else { return }
        onShare?(snapshot)
    }

    func seeAllHistory() {
        onSeeAllHistory?(marketId)
    }

    func perpetualInfo() {
        onPerpetualInfo?()
    }

    func more() {
        onMore?()
    }

    // MARK: - Terminal toast

    func showTradeResult(_ toast: TradeToast) {
        terminalToastTask?.cancel()
        terminalToast = toast
        recompute()
        terminalToastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.terminalToast = nil
            self?.recompute()
        }
    }
}

extension PerpsAssetPageViewModel {
    enum MarketInput: Equatable {
        case loading
        case failed
        case notFound
        case ready(snapshot: PerpsAssetMarketSnapshot, markPrice: Double?, sizeDecimals: Int)

        var snapshot: PerpsAssetMarketSnapshot? {
            guard case let .ready(snapshot, _, _) = self else { return nil }
            return snapshot
        }
    }
}

private extension PerpsAssetPageViewModel {
    func observeStores() {
        store.addObserver(self) { observer, _ in
            Task { @MainActor in observer.applyMarketsStoreState() }
        }
        marketDetailsStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.recompute() }
        }
        accountStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.recompute() }
        }
        openPositionFlowCancellable = openPositionFlow.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.recompute() }
        }
    }

    func applyMarketsStoreState() {
        livePrice = store.getState().livePrice(marketId: marketId)
        recompute()
    }

    var isAccountActive: Bool {
        if case .active = accountStore.currentWalletState() { return true }
        return false
    }

    func recompute() {
        let market = currentMarketInput()
        if case let .ready(_, markPrice, _) = market, let markPrice {
            lastMarkPrice = markPrice
        }
        let lifecycle = accountStore.lifecycle(marketId: marketId)
        let extras = accountStore.marketExtras(marketId: marketId)
        state = Self.reduce(
            market: market,
            lifecycle: lifecycle,
            extras: extras,
            isAccountActive: isAccountActive,
            isOpenPositionSubmitting: openPositionFlow.isSubmitting,
            previous: state
        )
        chartMarkers = Self.chartMarkers(lifecycle: lifecycle, extras: extras)
        tradeToast = terminalToast ?? Self.lifecycleToast(lifecycle)
    }

    func currentMarketInput() -> MarketInput {
        switch marketDetailsStore.getState() {
        case .idle, .loading:
            return .loading
        case .failed:
            return .failed
        case .notFound:
            return .notFound
        case let .loaded(snapshot):
            guard snapshot.marketId == marketId else { return .loading }
            let overlaid = snapshot.overlayingLivePrice(livePrice)
            let markPrice = livePrice ?? (overlaid.hasPrice ? overlaid.price : nil)
            return .ready(snapshot: overlaid, markPrice: markPrice, sizeDecimals: overlaid.sizeDecimals)
        }
    }

    func currentShareSnapshot() -> SharePositionSnapshot? {
        guard let ready = state.ready,
              let markPrice = lastMarkPrice,
              let summary = Self.summaryForLifecycle(accountStore.lifecycle(marketId: marketId))
        else { return nil }
        return SharePositionSnapshot(
            coinName: ready.title,
            iconLetter: ready.iconLetter,
            iconURL: ready.iconURL,
            isLong: summary.side == .long,
            leverage: summary.leverage,
            entryPrice: summary.entryPrice,
            currentPrice: markPrice,
            pnlPercent: summary.roiPercent,
            isProfit: summary.unrealizedPnlUsd >= 0,
            date: Date()
        )
    }
}

// MARK: - Pure mapping (no store access, no `self`) — directly unit-testable

extension PerpsAssetPageViewModel {
    nonisolated static func reduce(
        market: MarketInput,
        lifecycle: PerpsMarketLifecycle,
        extras: PerpsMarketExtras?,
        isAccountActive: Bool,
        isOpenPositionSubmitting: Bool,
        previous: State
    ) -> State {
        switch market {
        case .loading:
            return previous.ready != nil ? previous : .loading
        case .failed:
            return previous.ready != nil ? previous : .failed
        case .notFound:
            return previous.ready != nil ? previous : .notFound
        case let .ready(snapshot, markPrice, sizeDecimals):
            return .ready(makeReady(
                snapshot: snapshot,
                markPrice: markPrice,
                sizeDecimals: sizeDecimals,
                lifecycle: lifecycle,
                extras: extras,
                isAccountActive: isAccountActive,
                isOpenPositionSubmitting: isOpenPositionSubmitting
            ))
        }
    }

    nonisolated static func makeReady(
        snapshot: PerpsAssetMarketSnapshot,
        markPrice: Double?,
        sizeDecimals: Int,
        lifecycle: PerpsMarketLifecycle,
        extras: PerpsMarketExtras?,
        isAccountActive: Bool,
        isOpenPositionSubmitting: Bool
    ) -> Ready {
        let summary = summaryForLifecycle(lifecycle)
        let flags = extras?.flags
        let triggerOrders = summary != nil ? (extras?.triggerOrders ?? []) : []
        let autoClose = extras?.autoCloseKnown == true
            ? autoCloseAffordance(orders: triggerOrders, hasPosition: summary != nil)
            : AutoCloseAffordance.none
        let positionMark = markPrice ?? snapshot.price
        return Ready(
            title: snapshot.displayName,
            symbol: snapshot.symbol,
            iconLetter: snapshot.symbol.prefix(1).uppercased(),
            iconURL: snapshot.iconURL,
            priceText: snapshot.hasPrice ? PerpsFormatting.usd(snapshot.price) : "",
            changePercentText: PerpsFormatting.signedPercent(snapshot.priceChangePercent),
            changeAmountText: PerpsFormatting.signedUsd(snapshot.priceChangeAmount),
            isChangePositive: snapshot.priceChangePercent >= 0,
            volumeText: PerpsFormatting.usd(snapshot.volume24h),
            openInterestText: PerpsFormatting.usd(snapshot.openInterest),
            fundingText: snapshot.fundingRatePercent.map { PerpsFormatting.funding(percent: $0) },
            about: snapshot.about,
            position: summary.map { makePosition($0, markPrice: positionMark, sizeDecimals: sizeDecimals) },
            limitOrders: (extras?.limitOrders ?? []).map { makeLimitOrder($0, symbol: snapshot.symbol, sizeDecimals: sizeDecimals) },
            orders: triggerOrders.map { makeTriggerOrder($0, position: summary) },
            autoClose: autoClose,
            history: (extras?.recentActivity ?? []).map { makeActivityRow($0, symbol: snapshot.symbol) },
            canAdjustMargin: (flags?.addMarginEnabled ?? false) || (flags?.removeMarginEnabled ?? false),
            canEditAutoClose: flags?.autoCloseEnabled ?? false,
            canCancelOrders: flags?.cancelEnabled ?? false,
            actions: actions(
                for: lifecycle,
                snapshot: snapshot,
                flags: flags,
                isAccountActive: isAccountActive,
                isOpenPositionSubmitting: isOpenPositionSubmitting
            )
        )
    }

    nonisolated static func actions(
        for lifecycle: PerpsMarketLifecycle,
        snapshot: PerpsAssetMarketSnapshot,
        flags: PerpsTradingFlags?,
        isAccountActive: Bool,
        isOpenPositionSubmitting: Bool
    ) -> Actions {
        let canOpen = isOpenAllowed(snapshot: snapshot, flags: flags, isAccountActive: isAccountActive)
        let canClose = isCloseAllowed(flags: flags)
        let canResize = canOpen || canClose
        switch lifecycle {
        case .flat:
            return .longShort(enabled: canOpen && !isOpenPositionSubmitting)
        case .opening:
            return .hidden
        case .open:
            return .editCashOut(editEnabled: canResize, cashOutEnabled: canClose)
        case .closing, .adjusting, .adjustingMargin:
            return .editCashOut(editEnabled: false, cashOutEnabled: false)
        }
    }

    nonisolated static func isOpenAllowed(
        snapshot: PerpsAssetMarketSnapshot?,
        flags: PerpsTradingFlags?,
        isAccountActive: Bool
    ) -> Bool {
        guard isAccountActive else { return snapshot?.isTradingEnabled ?? false }
        return flags?.openEnabled ?? false
    }

    nonisolated static func isCloseAllowed(flags: PerpsTradingFlags?) -> Bool {
        flags?.closeEnabled ?? false
    }

    nonisolated static func editDirections(
        snapshot: PerpsAssetMarketSnapshot?,
        flags: PerpsTradingFlags?,
        isAccountActive: Bool
    ) -> Set<PerpsSizeChangeDirection> {
        var directions = Set<PerpsSizeChangeDirection>()
        if isOpenAllowed(snapshot: snapshot, flags: flags, isAccountActive: isAccountActive) { directions.insert(.add) }
        if isCloseAllowed(flags: flags) { directions.insert(.reduce) }
        return directions
    }

    nonisolated static func chartMarkers(lifecycle: PerpsMarketLifecycle, extras: PerpsMarketExtras?) -> [PerpsChartPositionMarker] {
        guard let summary = summaryForLifecycle(lifecycle) else { return [] }
        var markers: [PerpsChartPositionMarker] = []
        if summary.entryPrice > 0 {
            markers.append(PerpsChartPositionMarker(kind: .entry, price: summary.entryPrice))
        }
        if summary.liquidationPrice > 0 {
            markers.append(PerpsChartPositionMarker(kind: .liquidation, price: summary.liquidationPrice))
        }
        let orders = (extras?.triggerOrders ?? []).filter { $0.triggerPrice > 0 }
        if let tp = nearestToEntry(orders.filter { $0.kind == .takeProfit }, entry: summary.entryPrice) {
            markers.append(PerpsChartPositionMarker(kind: .takeProfit, price: tp.triggerPrice))
        }
        if let sl = nearestToEntry(orders.filter { $0.kind == .stopLoss }, entry: summary.entryPrice) {
            markers.append(PerpsChartPositionMarker(kind: .stopLoss, price: sl.triggerPrice))
        }
        return markers
    }

    private nonisolated static func nearestToEntry(_ orders: [PerpsTriggerOrderSummary], entry: Double) -> PerpsTriggerOrderSummary? {
        orders.min { abs($0.triggerPrice - entry) < abs($1.triggerPrice - entry) }
    }

    nonisolated static func summaryForLifecycle(_ lifecycle: PerpsMarketLifecycle) -> PerpsPositionSummary? {
        switch lifecycle {
        case let .open(summary), let .closing(summary), let .adjusting(summary, _), let .adjustingMargin(summary, _, _): summary
        case .flat, .opening: nil
        }
    }

    nonisolated static func makePosition(_ summary: PerpsPositionSummary, markPrice: Double, sizeDecimals: Int) -> Position {
        let distanceText = summary.liquidationDistancePercent.map {
            TKLocales.Perps.Asset.liquidationDistance(PerpsFormatting.signedPercent($0))
        }
        let sideText = (summary.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased()
        return Position(
            valueText: PerpsFormatting.usd(summary.equityUsd),
            pnlText: PerpsFormatting.signedUsd(summary.unrealizedPnlUsd),
            pnlPercentText: summary.roiPercent.map { PerpsFormatting.signedPercent($0) },
            isPnlPositive: summary.unrealizedPnlUsd >= 0,
            isLong: summary.side == .long,
            sideText: sideText,
            leverageText: summary.leverage.map { PerpsFormatting.leverage($0).uppercased() },
            sizeUsdText: PerpsFormatting.usd(summary.notionalUsd),
            sizeTokenText: PerpsFormatting.token(summary.baseSize, symbol: summary.symbol, decimals: sizeDecimals),
            liquidationText: PerpsFormatting.usd(summary.liquidationPrice),
            liquidationDistanceText: distanceText,
            markText: PerpsFormatting.usd(markPrice),
            entryText: PerpsFormatting.usd(summary.entryPrice),
            fundingText: summary.fundingPaidUsd.map { PerpsFormatting.signedUsd($0) } ?? PerpsFormatting.usd(0)
        )
    }

    nonisolated static func makeTriggerOrder(_ order: PerpsTriggerOrderSummary, position: PerpsPositionSummary?) -> TriggerOrder {
        let actionBase = order.side == .short ? TKLocales.Perps.Asset.sell : TKLocales.Perps.Asset.buy
        let action: String
        var valueText: String?
        var percentText: String?
        var isPositive = true
        if let position, position.baseSize > 0 {
            // A zero base marks a position-tied leg: the venue sizes it by the
            // live position, so project against the full position size.
            let effectiveBase = order.baseAmount > 0 ? order.baseAmount : position.baseSize
            action = "\(actionBase) \(position.reducePercent(baseAmount: effectiveBase))%"
            let projection = position.triggerProjection(triggerPrice: order.triggerPrice, baseAmount: effectiveBase)
            isPositive = projection.pnlUsd >= 0
            valueText = PerpsFormatting.signedUsd(projection.pnlUsd)
            percentText = projection.roePercent.map { PerpsFormatting.signedPercent($0) }
        } else {
            action = actionBase
        }
        let kindText = order.kind == .takeProfit ? TKLocales.Perps.OpenPosition.tp : TKLocales.Perps.OpenPosition.sl
        return TriggerOrder(
            id: "\(order.orderIndex)",
            actionText: action,
            kindText: kindText,
            isTakeProfit: order.kind == .takeProfit,
            priceText: PerpsFormatting.usd(order.triggerPrice),
            valueText: valueText,
            percentText: percentText,
            isPositive: isPositive
        )
    }

    nonisolated static func makeLimitOrder(
        _ order: PerpsLimitOrderSummary,
        symbol: String,
        sizeDecimals: Int
    ) -> LimitOrder {
        let action = order.side == .long ? TKLocales.Perps.Asset.buy : TKLocales.Perps.Asset.sell
        return LimitOrder(
            id: "limit-\(order.orderIndex)",
            orderIndex: order.orderIndex,
            actionText: "\(action) \(PerpsFormatting.token(order.remainingBaseAmount, symbol: symbol, decimals: sizeDecimals))",
            priceText: PerpsFormatting.usd(order.limitPrice),
            valueText: PerpsFormatting.usd(order.remainingBaseAmount * order.limitPrice)
        )
    }

    nonisolated static func autoCloseAffordance(orders: [PerpsTriggerOrderSummary], hasPosition: Bool) -> AutoCloseAffordance {
        guard hasPosition else { return .none }
        let hasTakeProfit = orders.contains { $0.kind == .takeProfit }
        let hasStopLoss = orders.contains { $0.kind == .stopLoss }
        switch (hasTakeProfit, hasStopLoss) {
        case (false, false): return .setAutoClose
        case (false, true): return .setTakeProfit
        case (true, false): return .setStopLoss
        case (true, true): return .none
        }
    }

    nonisolated static func makeActivityRow(_ item: PerpsActivityItem, symbol: String) -> ActivityRow {
        let side = item.positionSide.map { $0 == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short } ?? ""
        let title: String = switch item.outcome {
        case .liquidated: TKLocales.Perps.Asset.activityLiquidated(side)
        case .closed: TKLocales.Perps.Asset.activityClosed(side)
        case .opened: TKLocales.Perps.Asset.activityOpened(side)
        case .funding, .other: TKLocales.Perps.Asset.activityFunding
        }
        let amount: Double? = switch item.outcome {
        case .funding: item.usdAmount
        case .liquidated, .closed: item.realizedPnl
        case .opened, .other: nil
        }
        return ActivityRow(
            id: item.id,
            title: title,
            symbol: symbol,
            dateText: PerpsFormatting.candleDateTime(item.date),
            amountText: amount.map { PerpsFormatting.signedUsd($0) },
            isAmountPositive: (amount ?? 0) >= 0
        )
    }

    nonisolated static func lifecycleToast(_ lifecycle: PerpsMarketLifecycle) -> TradeToast? {
        switch lifecycle {
        case let .opening(descriptor):
            return .progress(openingToastText(descriptor))
        case let .closing(summary):
            return .progress(closeToastText(
                verb: TKLocales.Perps.Toast.closing,
                symbol: summary.symbol,
                side: summary.side,
                leverage: summary.leverage
            ))
        case let .adjusting(summary, direction):
            return .progress(closeToastText(
                verb: direction == .add ? TKLocales.Perps.Toast.increasing : TKLocales.Perps.Toast.reducing,
                symbol: summary.symbol,
                side: summary.side,
                leverage: summary.leverage
            ))
        case let .adjustingMargin(_, direction, amountUsd):
            return .progress(marginToastText(direction: direction, amountUsd: amountUsd, isDone: false))
        case .flat, .open:
            return nil
        }
    }

    /// Design pill copy for margin: "Adding $20 margin" / "Reducing margin by $10" —
    /// amount-based, unlike the size pills' "symbol side · leverage" pattern.
    nonisolated static func marginToastText(direction: KeeperCore.PerpsMarginChangeDirection, amountUsd: Double, isDone: Bool) -> String {
        let amount = PerpsFormatting.usd(amountUsd)
        switch direction {
        case .add: return isDone ? TKLocales.Perps.Toast.marginAdded(amount) : TKLocales.Perps.Toast.marginAdding(amount)
        case .reduce: return isDone ? TKLocales.Perps.Toast.marginReduced(amount) : TKLocales.Perps.Toast.marginReducing(amount)
        }
    }

    nonisolated static func openingToastText(_ descriptor: PerpsOpeningDescriptor) -> String {
        let verb = descriptor.isLimit ? TKLocales.Perps.Toast.placing : TKLocales.Perps.Toast.opening
        let sideText = (descriptor.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).lowercased()
        let margin = PerpsFormatting.usd(descriptor.marginUsd)
        let leverage = PerpsFormatting.leverage(descriptor.leverage)
        return "\(verb) \(descriptor.symbol) \(sideText): \(margin) · \(leverage)"
    }

    /// Design pill copy for close: "Closing BTC long · 27x" / "Closed BTC long · 27x".
    nonisolated static func closeToastText(verb: String, symbol: String, side: PerpsTradeSide, leverage: Double?) -> String {
        let sideText = (side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).lowercased()
        let leverageText = leverage.map { " · \(PerpsFormatting.leverage($0))" } ?? ""
        return "\(verb) \(symbol) \(sideText)\(leverageText)"
    }
}

extension PerpsAssetPageViewModel.State {
    var ready: PerpsAssetPageViewModel.Ready? {
        if case let .ready(ready) = self { ready } else { nil }
    }
}

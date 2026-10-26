import Combine
import Foundation
import PerpsModels
import SwiftUI
import TKLocalize
import TKLogging

@MainActor
final class PerpsAssetPageViewModel: ObservableObject, PerpsAssetPageViewModeling {
    typealias Position = PerpsAssetPagePosition
    typealias AutoCloseAffordance = PerpsAssetPageAutoCloseAffordance
    typealias TriggerOrder = PerpsAssetPageTriggerOrder
    typealias LimitOrder = PerpsAssetPageLimitOrder
    typealias ActivityRow = PerpsAssetPageActivityRow
    typealias Actions = PerpsAssetPageActions
    typealias Ready = PerpsAssetPageReady
    typealias State = PerpsAssetPageState
    typealias TradeToast = PerpsAssetPageTradeToast

    @Published private(set) var state: State = .loading
    @Published private(set) var tradeToast: TradeToast?
    @Published private(set) var chartMarkers: [PerpsChartPositionMarker] = []

    var onBack: (() -> Void)?
    var onPerpetualInfo: (() -> Void)?
    var onRiskDisclosure: (() -> Void)?
    var onTrade: ((Int64, PerpsTradeSide) -> Void)?
    var onEdit: ((Int64, Set<PerpsSizeChangeDirection>) -> Void)?
    var onCashOut: ((Int64) -> Void)?
    var onAdjustMargin: ((Int64) -> Void)?
    var onAutoClose: ((Int64) -> Void)?
    var onLimitOrder: ((Int64, PerpsLimitOrderSummary) -> Void)?
    var onEditLimitOrder: ((Int64, PerpsLimitOrderSummary) -> Void)?
    var onCancelLimitOrder: ((Int64, PerpsLimitOrderSummary) -> Void)?
    var onShare: ((SharePositionSnapshot) -> Void)?
    var onSeeAllHistory: ((Int64) -> Void)?
    var onHistoryEvent: ((PerpsHistoryEvent) -> Void)?
    var presentsAutoCloseWhenReady = false
    /// A resting-order change is reconciling; its row and buttons stay disabled until it settles.
    var isLimitOrderBusy = false {
        didSet { if oldValue != isLimitOrderBusy { recompute() } }
    }

    let marketId: Int64
    var priceDecimals: Int? {
        guard case let .ready(snapshot, _, _) = currentMarketInput() else { return nil }
        return snapshot.priceDecimals
    }

    private let priceFeed: PerpsMarketPriceFeed
    private let marketDetailsStore: any PerpsMarketDetailsStoring
    private let accountStore: any PerpsAccountStoring
    private let openPositionFlow: PerpsOpenPositionFlow
    private var openPositionFlowCancellable: AnyCancellable?
    private var terminalToast: TradeToast?
    private var terminalToastTask: Task<Void, Never>?
    private var livePrice: Double?
    private(set) var lastMarkPrice: Double?
    private var isOnScreen = false

    private let format: PerpsFormatting

    init(
        marketId: Int64,
        store: any PerpsMarketsStoring,
        marketDetailsStore: any PerpsMarketDetailsStoring,
        accountStore: any PerpsAccountStoring,
        openPositionFlow: PerpsOpenPositionFlow,
        format: PerpsFormatting
    ) {
        self.format = format
        self.marketId = marketId
        priceFeed = PerpsMarketPriceFeed(marketId: marketId, store: store)
        self.marketDetailsStore = marketDetailsStore
        self.accountStore = accountStore
        self.openPositionFlow = openPositionFlow
        observeStores()
        recompute()
    }

    func onAppear() {
        isOnScreen = true
        priceFeed.subscribe()
        marketDetailsStore.load(marketId: marketId)
        accountStore.resolveIfNeeded()
        accountStore.subscribePositions()
        accountStore.loadMarketExtras(marketId: marketId)
        applyLivePrice(forceRecompute: true)
    }

    func onDisappear() {
        isOnScreen = false
        priceFeed.unsubscribe()
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
        guard let order = restingLimitOrder(orderIndex) else { return }
        onLimitOrder?(marketId, order)
    }

    func editLimitOrder(_ orderIndex: Int64) {
        guard let order = restingLimitOrder(orderIndex) else { return }
        onEditLimitOrder?(marketId, order)
    }

    func cancelLimitOrder(_ orderIndex: Int64) {
        guard let order = restingLimitOrder(orderIndex) else { return }
        onCancelLimitOrder?(marketId, order)
    }

    func share() {
        guard let snapshot = currentShareSnapshot() else { return }
        onShare?(snapshot)
    }

    func seeAllHistory() {
        onSeeAllHistory?(marketId)
    }

    func selectHistory(_ id: String) {
        guard let event = accountStore.marketExtras(marketId: marketId)?.recentActivity.first(where: { $0.id == id }) else { return }
        onHistoryEvent?(event)
    }

    func perpetualInfo() {
        onPerpetualInfo?()
    }

    func riskDisclosure() {
        onRiskDisclosure?()
    }

    // MARK: - Terminal toast

    func showTradeResult(_ toast: TradeToast) {
        Log.perps.i("toast \(toast)")
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

    /// Takes `toast` down early, as when what it announced was canceled; a newer toast stays.
    func dismissTradeResult(_ toast: TradeToast) {
        guard terminalToast == toast else { return }
        terminalToastTask?.cancel()
        terminalToast = nil
        recompute()
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
        priceFeed.observe(self) { $0.applyLivePrice() }
        marketDetailsStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.recompute() }
        }
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.recompute() }
        }
        openPositionFlowCancellable = openPositionFlow.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.recompute() }
        }
    }

    func applyLivePrice(forceRecompute: Bool = false) {
        let price = priceFeed.livePrice
        guard forceRecompute || livePrice != price else { return }
        livePrice = price
        recompute()
    }

    var isAccountActive: Bool {
        if case let .active(account) = accountStore.currentWalletState() { return Self.tradingFlagsApply(to: account) }
        return false
    }

    func recompute() {
        let market = currentMarketInput()
        if case let .ready(_, markPrice, _) = market, let markPrice {
            lastMarkPrice = markPrice
        }
        let lifecycle = accountStore.lifecycle(marketId: marketId)
        let extras = accountStore.marketExtras(marketId: marketId)
        let newState = Self.reduce(
            market: market,
            lifecycle: lifecycle,
            extras: extras,
            isAccountActive: isAccountActive,
            isOpenPositionSubmitting: openPositionFlow.isSubmitting,
            isLimitOrderBusy: isLimitOrderBusy,
            previous: state,
            format: format
        )
        if state != newState {
            state = newState
        }
        let newChartMarkers = Self.chartMarkers(lifecycle: lifecycle, extras: extras)
        if chartMarkers != newChartMarkers {
            chartMarkers = newChartMarkers
        }
        let newTradeToast = terminalToast ?? Self.lifecycleToast(lifecycle, format: format)
        if tradeToast != newTradeToast {
            tradeToast = newTradeToast
        }
        presentAutoCloseIfRequested(lifecycle: lifecycle, extras: extras)
    }

    func presentAutoCloseIfRequested(lifecycle: PerpsMarketLifecycle, extras: PerpsMarketExtras?) {
        guard presentsAutoCloseWhenReady, isOnScreen, state.ready != nil else { return }
        guard case .open = lifecycle else {
            switch accountStore.currentWalletState() {
            case .unresolved, .resolving:
                return
            case let .active(account) where !account.positionsLoaded:
                return
            case .unbound, .inactive, .active:
                presentsAutoCloseWhenReady = false
                return
            }
        }
        guard let extras, extras.autoCloseKnown else { return }
        presentsAutoCloseWhenReady = false
        if extras.flags.canEditAutoClose {
            onAutoClose?(marketId)
        }
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

    func restingLimitOrder(_ orderIndex: Int64) -> PerpsLimitOrderSummary? {
        guard let order = accountStore.marketExtras(marketId: marketId)?.limitOrders.first(where: {
            $0.orderIndex == orderIndex
        }) else {
            accountStore.loadMarketExtras(marketId: marketId)
            return nil
        }
        return order
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
        isLimitOrderBusy: Bool,
        previous: State,
        format: PerpsFormatting
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
                isOpenPositionSubmitting: isOpenPositionSubmitting,
                isLimitOrderBusy: isLimitOrderBusy,
                format: format
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
        isOpenPositionSubmitting: Bool,
        isLimitOrderBusy: Bool,
        format: PerpsFormatting
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
            priceText: snapshot.hasPrice ? format.usd(snapshot.price) : "",
            changePercentText: format.signedPercent(snapshot.priceChangePercent),
            changeAmountText: format.signedUsd(snapshot.priceChangeAmount),
            isChangePositive: snapshot.priceChangePercent >= 0,
            volumeText: format.usd(snapshot.volume24h),
            openInterestText: format.usd(snapshot.openInterest),
            fundingText: snapshot.fundingRatePercent.map { format.funding(percent: $0) },
            about: snapshot.about,
            position: summary.map {
                makePosition(
                    $0,
                    markPrice: positionMark,
                    sizeDecimals: sizeDecimals,
                    isPending: isPending(lifecycle),
                    format: format
                )
            },
            limitOrders: (extras?.limitOrders ?? []).map { makeLimitOrder($0, format: format) },
            orders: triggerOrders.map { makeTriggerOrder($0, position: summary, format: format) },
            autoClose: autoClose,
            history: (extras?.recentActivity ?? []).map { makeActivityRow($0, format: format) },
            canAdjustMargin: flags.canAddMargin || flags.canRemoveMargin,
            canEditAutoClose: flags.canEditAutoClose,
            canCancelOrders: flags.canCancelOrders && !isLimitOrderBusy,
            isLimitOrderBusy: isLimitOrderBusy,
            actions: actions(
                for: lifecycle,
                snapshot: snapshot,
                restingLimitOrder: extras?.limitOrders.first,
                flags: flags,
                isAccountActive: isAccountActive,
                isOpenPositionSubmitting: isOpenPositionSubmitting,
                isLimitOrderBusy: isLimitOrderBusy
            )
        )
    }

    nonisolated static func actions(
        for lifecycle: PerpsMarketLifecycle,
        snapshot: PerpsAssetMarketSnapshot,
        restingLimitOrder: PerpsLimitOrderSummary?,
        flags: PerpsTradingFlags?,
        isAccountActive: Bool,
        isOpenPositionSubmitting: Bool,
        isLimitOrderBusy: Bool
    ) -> Actions {
        let canOpen = isOpenAllowed(snapshot: snapshot, flags: flags, isAccountActive: isAccountActive)
        let canClose = isCloseAllowed(flags: flags)
        let canResize = canOpen || canClose
        switch lifecycle {
        case .flat:
            if let restingLimitOrder {
                return .editCancelLimitOrder(orderIndex: restingLimitOrder.orderIndex, enabled: flags.canCancelOrders && !isLimitOrderBusy)
            }
            return .longShort(enabled: canOpen && !isOpenPositionSubmitting)
        case .opening:
            return .hidden
        case .open:
            return .editCashOut(editEnabled: canResize, cashOutEnabled: canClose)
        case .closing, .adjusting, .adjustingMargin:
            return .editCashOut(editEnabled: false, cashOutEnabled: false)
        }
    }

    nonisolated static func tradingFlagsApply(to account: PerpsAccount) -> Bool {
        !account.needsActivation || (account.hasTradingKey && account.hasReadOnlyToken)
    }

    nonisolated static func isOpenAllowed(
        snapshot: PerpsAssetMarketSnapshot?,
        flags: PerpsTradingFlags?,
        isAccountActive: Bool
    ) -> Bool {
        guard isAccountActive else { return snapshot?.isTradingEnabled ?? false }
        return flags.canOpen
    }

    nonisolated static func isCloseAllowed(flags: PerpsTradingFlags?) -> Bool {
        flags.canClose
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

    nonisolated static func isPending(_ lifecycle: PerpsMarketLifecycle) -> Bool {
        switch lifecycle {
        case .closing, .adjusting, .adjustingMargin: true
        case .flat, .open, .opening: false
        }
    }

    nonisolated static func makePosition(
        _ summary: PerpsPositionSummary,
        markPrice: Double,
        sizeDecimals: Int,
        isPending: Bool,
        format: PerpsFormatting
    ) -> Position {
        let distanceText = summary.liquidationDistancePercent.map {
            TKLocales.Perps.Asset.liquidationDistance(format.signedPercent($0))
        }
        let sideText = (summary.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased()
        return Position(
            valueText: format.usd(summary.equityUsd),
            isPending: isPending,
            pnlText: format.signedUsd(summary.unrealizedPnlUsd),
            pnlPercentText: summary.roiPercent.map { format.signedPercent($0) },
            isPnlPositive: summary.unrealizedPnlUsd >= 0,
            isLong: summary.side == .long,
            sideText: sideText,
            leverageText: summary.leverage.map { format.leverage($0).uppercased() },
            sizeUsdText: format.usd(summary.notionalUsd),
            sizeTokenText: format.token(summary.baseSize, symbol: summary.symbol, decimals: sizeDecimals),
            liquidationText: format.usd(summary.liquidationPrice),
            liquidationDistanceText: distanceText,
            markText: format.usd(markPrice),
            entryText: format.usd(summary.entryPrice),
            fundingText: summary.fundingPaidUsd.map { format.signedUsd($0) } ?? format.usd(0)
        )
    }

    nonisolated static func makeTriggerOrder(
        _ order: PerpsTriggerOrderSummary,
        position: PerpsPositionSummary?,
        format: PerpsFormatting
    ) -> TriggerOrder {
        let closingSide = position?.side ?? (order.side == .short ? .long : .short)
        let action = closingSide == .short ? TKLocales.Perps.Asset.closeShort : TKLocales.Perps.Asset.closeLong
        var valueText: String?
        var percentText: String?
        var isPositive = true
        if let position, position.baseSize > 0 {
            // A zero base marks a position-tied leg: the venue sizes it by the
            // live position, so project against the full position size.
            let effectiveBase = order.baseAmount > 0 ? order.baseAmount : position.baseSize
            let projection = position.triggerProjection(triggerPrice: order.triggerPrice, baseAmount: effectiveBase)
            isPositive = projection.pnlUsd >= 0
            valueText = format.signedUsd(projection.pnlUsd)
            percentText = projection.roePercent.map { format.signedPercent($0) }
        }
        let kindText = order.kind == .takeProfit ? TKLocales.Perps.OpenPosition.tp : TKLocales.Perps.OpenPosition.sl
        return TriggerOrder(
            id: "\(order.orderIndex)",
            actionText: action,
            kindText: kindText,
            isTakeProfit: order.kind == .takeProfit,
            priceText: format.usd(order.triggerPrice),
            valueText: valueText,
            percentText: percentText,
            isPositive: isPositive
        )
    }

    nonisolated static func makeLimitOrder(_ order: PerpsLimitOrderSummary, format: PerpsFormatting) -> LimitOrder {
        LimitOrder(
            id: "limit-\(order.orderIndex)",
            orderIndex: order.orderIndex,
            limitPriceText: format.usd(order.limitPrice),
            captionText: order.expiresAtSeconds > 0
                ? TKLocales.Perps.Asset.limitPriceExpires(format.dayMonth(Date(timeIntervalSince1970: TimeInterval(order.expiresAtSeconds))))
                : TKLocales.Perps.Asset.limitPrice,
            sideText: (order.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased(),
            isLong: order.side == .long
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

    nonisolated static func makeActivityRow(_ event: PerpsHistoryEvent, format: PerpsFormatting) -> ActivityRow {
        ActivityRow(
            id: event.id,
            icon: PerpsHistoryEventText.icon(event.kind),
            title: PerpsHistoryEventText.title(event),
            subtitle: TKLocales.MultichainHistory.Perps.subtitle(event.symbol),
            dateText: format.candleDateTime(event.date),
            amountText: event.isClosing ? event.pnl.map(format.signedUsd) : event.margin.map(format.usd),
            amountStyle: event.isClosing ? ((event.pnl ?? 0) >= 0 ? .positive : .negative) : .primary
        )
    }

    nonisolated static func lifecycleToast(_ lifecycle: PerpsMarketLifecycle, format: PerpsFormatting) -> TradeToast? {
        switch lifecycle {
        case let .opening(descriptor):
            return .progress(openingToastText(descriptor, format: format))
        case let .closing(summary):
            return .progress(closeToastText(
                verb: TKLocales.Perps.Toast.closing,
                symbol: summary.symbol,
                side: summary.side,
                leverage: summary.leverage,
                format: format
            ))
        case let .adjusting(summary, direction):
            return .progress(closeToastText(
                verb: direction == .add ? TKLocales.Perps.Toast.increasing : TKLocales.Perps.Toast.reducing,
                symbol: summary.symbol,
                side: summary.side,
                leverage: summary.leverage,
                format: format
            ))
        case let .adjustingMargin(_, direction, amountUsd):
            return .progress(marginToastText(direction: direction, amountUsd: amountUsd, isDone: false, format: format))
        case .flat, .open:
            return nil
        }
    }

    /// Design pill copy for margin: "Adding $20 margin" / "Reducing margin by $10" —
    /// amount-based, unlike the size pills' "symbol side · leverage" pattern.
    nonisolated static func marginToastText(
        direction: PerpsModels.PerpsMarginChangeDirection,
        amountUsd: Double,
        isDone: Bool,
        format: PerpsFormatting
    ) -> String {
        let amount = format.usd(amountUsd)
        switch direction {
        case .add: return isDone ? TKLocales.Perps.Toast.marginAdded(amount) : TKLocales.Perps.Toast.marginAdding(amount)
        case .reduce: return isDone ? TKLocales.Perps.Toast.marginReduced(amount) : TKLocales.Perps.Toast.marginReducing(amount)
        }
    }

    nonisolated static func limitOrderChangeToastText(_ kind: PerpsLimitOrderChangeKind, isDone: Bool) -> String {
        switch kind {
        case .cancel: isDone ? TKLocales.Perps.Toast.orderCancelled : TKLocales.Perps.Toast.orderCancelling
        case .modify: isDone ? TKLocales.Perps.Toast.orderUpdated : TKLocales.Perps.Toast.orderUpdating
        }
    }

    nonisolated static func openingToastText(_ descriptor: PerpsOpeningDescriptor, format: PerpsFormatting) -> String {
        let verb = descriptor.isLimit ? TKLocales.Perps.Toast.placing : TKLocales.Perps.Toast.opening
        let sideText = (descriptor.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).lowercased()
        let margin = format.usd(descriptor.marginUsd)
        let leverage = format.leverage(descriptor.leverage)
        return "\(verb) \(descriptor.symbol) \(sideText): \(margin) · \(leverage)"
    }

    /// Design pill copy for close: "Closing BTC long · 27x" / "Closed BTC long · 27x".
    nonisolated static func closeToastText(
        verb: String,
        symbol: String,
        side: PerpsTradeSide,
        leverage: Double?,
        format: PerpsFormatting
    ) -> String {
        let sideText = (side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).lowercased()
        let leverageText = leverage.map { " · \(format.leverage($0))" } ?? ""
        return "\(verb) \(symbol) \(sideText)\(leverageText)"
    }
}

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

    @Published private(set) var state: State = .loading(hasPosition: false)
    @Published private(set) var tradeToast: TradeToast?
    @Published private(set) var chartMarkers: [PerpsChartPositionMarker] = []
    @Published private(set) var showsLoyaltyBanner = false

    var onBack: (() -> Void)?
    var onPerpetualInfo: (() -> Void)?
    var onRiskDisclosure: (() -> Void)?
    var onTrade: ((PerpsMarketScreenContext, PerpsTradeSide) -> Void)?
    var onEdit: ((PerpsMarketScreenContext, Set<PerpsSizeChangeDirection>) -> Void)?
    var onCashOut: ((PerpsMarketScreenContext) -> Void)?
    var onAdjustMargin: ((PerpsMarketScreenContext) -> Void)?
    var onAutoClose: ((PerpsMarketScreenContext) -> Void)?
    var onLimitOrder: ((PerpsMarketScreenContext, PerpsLimitOrderSummary) -> Void)?
    var onEditLimitOrder: ((PerpsMarketScreenContext, PerpsLimitOrderSummary) -> Void)?
    var onCancelLimitOrder: ((Int64, PerpsLimitOrderSummary) -> Void)?
    var onShare: ((SharePositionSnapshot, AnyPublisher<SharePositionSnapshot, Never>) -> Void)?
    var onSeeAllHistory: ((Int64) -> Void)?
    var onHistoryEvent: ((PerpsHistoryEvent) -> Void)?
    var onLoadFailed: (() -> Void)?
    var onOpenLoyalty: (() -> Void)?
    var presentsAutoCloseWhenReady = false
    /// A resting-order change is reconciling; its row and buttons stay disabled until it settles.
    private(set) var isLimitOrderBusy = false {
        didSet { if oldValue != isLimitOrderBusy { recompute() } }
    }

    let marketId: Int64

    private let priceFeed: PerpsMarketPriceFeed
    private let marketDetailsStore: any PerpsMarketDetailsStoring
    private let accountStore: any PerpsAccountStoring
    private let openPositionFlow: PerpsOpenPositionFlow
    private var openPositionFlowCancellable: AnyCancellable?
    private let tradeOutcomes: @MainActor () -> AsyncStream<PerpsTradeRunner.Outcome>
    private var tradeOutcomesTask: Task<Void, Never>?
    private var terminalToast: TradeToast?
    private var terminalToastTask: Task<Void, Never>?
    private var livePrice: Double?
    private(set) var lastMarkPrice: Double?
    private let didRecompute = PassthroughSubject<Void, Never>()
    private var isOnScreen = false
    private var isSubscribed = false

    private let format: PerpsFormatting
    private let loyalty: PerpsLoyalty?
    private var isLoyaltyBannerAllowed = false
    private var loyaltyReloadTask: Task<Void, Never>?

    init(
        marketId: Int64,
        store: any PerpsMarketsStoring,
        marketDetailsStore: any PerpsMarketDetailsStoring,
        accountStore: any PerpsAccountStoring,
        openPositionFlow: PerpsOpenPositionFlow,
        tradeOutcomes: @escaping @MainActor () -> AsyncStream<PerpsTradeRunner.Outcome>,
        format: PerpsFormatting,
        loyalty: PerpsLoyalty?
    ) {
        self.tradeOutcomes = tradeOutcomes
        self.loyalty = loyalty
        self.format = format
        self.marketId = marketId
        priceFeed = PerpsMarketPriceFeed(marketId: marketId, store: store)
        self.marketDetailsStore = marketDetailsStore
        self.accountStore = accountStore
        self.openPositionFlow = openPositionFlow
        observeStores()
        recompute()
    }

    deinit {
        tradeOutcomesTask?.cancel()
        loyaltyReloadTask?.cancel()
    }

    func onWillAppear() {
        isOnScreen = true
        isLoyaltyBannerAllowed = loyalty?.showsBanner() ?? false
        reloadLoyalty()
        observeTradeOutcomes()
        applyLivePrice(forceRecompute: true)
    }

    func onAppear() {
        isOnScreen = true
        guard !isSubscribed else { return }
        isSubscribed = true
        priceFeed.subscribe()
        marketDetailsStore.load(marketId: marketId)
        accountStore.resolveIfNeeded()
        accountStore.subscribePositions()
        accountStore.loadMarketExtras(marketId: marketId)
        applyLivePrice(forceRecompute: true)
    }

    func onDisappear() {
        isOnScreen = false
        tradeOutcomesTask?.cancel()
        tradeOutcomesTask = nil
        guard isSubscribed else { return }
        isSubscribed = false
        priceFeed.unsubscribe()
        accountStore.unsubscribePositions()
        accountStore.releaseMarketExtras(marketId: marketId)
    }

    func retry() {
        marketDetailsStore.load(marketId: marketId)
        accountStore.refresh()
        accountStore.loadMarketExtras(marketId: marketId)
    }

    /// The runner has refreshed the account already, and that refresh reloads the extras of
    /// every market on screen; loading either here again only repeated the same reads.
    func reloadAfterTrade() {
        marketDetailsStore.load(marketId: marketId)
    }

    func openLoyalty() {
        onOpenLoyalty?()
    }

    func dismissLoyaltyBanner() {
        loyaltyReloadTask?.cancel()
        loyalty?.hideBanner()
        isLoyaltyBannerAllowed = false
        showsLoyaltyBanner = false
    }

    private func reloadLoyalty() {
        guard let loyalty else { return }
        loyaltyReloadTask?.cancel()
        loyaltyReloadTask = Task { [weak self] in
            await loyalty.reload()
            guard let self, !Task.isCancelled else { return }
            isLoyaltyBannerAllowed = loyalty.showsBanner()
            recompute()
        }
    }

    func long() {
        guard let screen = screenContext() else { return }
        onTrade?(screen, .long)
    }

    func short() {
        guard let screen = screenContext() else { return }
        onTrade?(screen, .short)
    }

    func edit() {
        guard let screen = screenContext() else { return }
        onEdit?(screen, Self.editDirections(
            snapshot: screen.market,
            flags: accountStore.marketExtras(marketId: marketId)?.flags,
            isAccountActive: isAccountActive
        ))
    }

    func cashOut() {
        guard let screen = screenContext() else { return }
        onCashOut?(screen)
    }

    func adjustMargin() {
        guard let screen = screenContext() else { return }
        onAdjustMargin?(screen)
    }

    func autoClose() {
        guard let screen = screenContext() else { return }
        onAutoClose?(screen)
    }

    func limitOrder(_ orderIndex: Int64) {
        guard let order = restingLimitOrder(orderIndex), let screen = screenContext() else { return }
        onLimitOrder?(screen, order)
    }

    func editLimitOrder(_ orderIndex: Int64) {
        guard let order = restingLimitOrder(orderIndex), let screen = screenContext() else { return }
        onEditLimitOrder?(screen, order)
    }

    func cancelLimitOrder(_ orderIndex: Int64) {
        guard let order = restingLimitOrder(orderIndex) else { return }
        onCancelLimitOrder?(marketId, order)
    }

    func share() {
        let date = Date()
        guard let snapshot = currentShareSnapshot(date: date) else { return }
        let updates = didRecompute
            .compactMap { [weak self] in self?.currentShareSnapshot(date: date) }
            .removeDuplicates()
            .eraseToAnyPublisher()
        onShare?(snapshot, updates)
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
        Self.playHaptic(for: toast)
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

    private static func playHaptic(for toast: TradeToast) {
        switch toast {
        case .progress:
            return
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .unknown:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .failure:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
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
    /// A trade form covers the page full screen while its market keeps ticking; `onWillAppear` catches up.
    func observeStores() {
        priceFeed.observe(self) { observer in
            guard observer.isOnScreen else { return }
            observer.applyLivePrice()
        }
        marketDetailsStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.recomputeOnScreen() }
        }
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.recomputeOnScreen() }
        }
        openPositionFlowCancellable = openPositionFlow.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.recomputeOnScreen() }
        }
    }

    func observeTradeOutcomes() {
        guard tradeOutcomesTask == nil else { return }
        let outcomes = tradeOutcomes()
        tradeOutcomesTask = Task { [weak self] in
            for await outcome in outcomes {
                self?.apply(outcome)
            }
        }
    }

    func apply(_ outcome: PerpsTradeRunner.Outcome) {
        switch outcome {
        case let .toast(toast):
            showTradeResult(toast)
        case let .dismissToast(toast):
            dismissTradeResult(toast)
        case .reload:
            reloadAfterTrade()
        case let .busy(isBusy):
            isLimitOrderBusy = isBusy
        }
    }

    func recomputeOnScreen() {
        guard isOnScreen else { return }
        recompute()
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

    func currentLifecycle() -> PerpsMarketLifecycle {
        let lifecycle = accountStore.lifecycle(marketId: marketId)
        guard case .flat = lifecycle, let trade = openPositionFlow.activeTrade(marketId: marketId) else { return lifecycle }
        return .opening(trade)
    }

    func recompute() {
        let market = currentMarketInput()
        if case let .ready(_, markPrice, _) = market, let markPrice {
            lastMarkPrice = markPrice
        }
        let lifecycle = currentLifecycle()
        let extras = accountStore.marketExtras(marketId: marketId)
        let newState = Self.reduce(
            market: market,
            lifecycle: lifecycle,
            extras: extras,
            isAccountActive: isAccountActive,
            isLimitOrderBusy: isLimitOrderBusy,
            previous: state,
            format: format
        )
        if state != newState {
            state = newState
            if newState == .failed {
                onLoadFailed?()
            }
        }
        let newChartMarkers = Self.chartMarkers(lifecycle: lifecycle, extras: extras)
        if chartMarkers != newChartMarkers {
            chartMarkers = newChartMarkers
        }
        let newTradeToast = terminalToast ?? Self.lifecycleToast(lifecycle, format: format)
        if tradeToast != newTradeToast {
            tradeToast = newTradeToast
        }
        let showsLoyaltyBanner = isLoyaltyBannerAllowed && isKnownFlat(lifecycle)
        if self.showsLoyaltyBanner != showsLoyaltyBanner {
            self.showsLoyaltyBanner = showsLoyaltyBanner
        }
        presentAutoCloseIfRequested(lifecycle: lifecycle, extras: extras)
        didRecompute.send()
    }

    private func isKnownFlat(_ lifecycle: PerpsMarketLifecycle) -> Bool {
        guard case .flat = lifecycle else { return false }
        switch accountStore.currentWalletState() {
        case .unresolved, .resolving:
            return false
        case let .active(account):
            return account.positionsLoaded
        case .unbound, .inactive:
            return true
        }
    }

    func presentAutoCloseIfRequested(lifecycle: PerpsMarketLifecycle, extras: PerpsMarketExtras?) {
        guard presentsAutoCloseWhenReady, isOnScreen, isSubscribed, state.ready != nil else { return }
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
            autoClose()
        }
    }

    func screenContext() -> PerpsMarketScreenContext? {
        guard let market = currentMarketInput().snapshot else { return nil }
        return PerpsMarketScreenContext(
            market: market,
            markPrice: lastMarkPrice,
            lifecycle: currentLifecycle()
        )
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

    func currentShareSnapshot(date: Date) -> SharePositionSnapshot? {
        guard let ready = state.ready,
              let summary = Self.summaryForLifecycle(currentLifecycle()),
              let currentPrice = lastMarkPrice ?? summary.markPrice
        else { return nil }
        return SharePositionSnapshot(
            coinName: ready.title,
            iconLetter: ready.iconLetter,
            iconURL: ready.iconURL,
            isLong: summary.side == .long,
            leverage: summary.leverage,
            entryPrice: summary.entryPrice,
            currentPrice: currentPrice,
            pnlPercent: summary.roiPercent,
            isProfit: summary.unrealizedPnlUsd >= 0,
            date: date
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
        isLimitOrderBusy: Bool,
        previous: State,
        format: PerpsFormatting
    ) -> State {
        switch market {
        case .loading:
            return previous.ready != nil ? previous : .loading(hasPosition: summaryForLifecycle(lifecycle) != nil)
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
            priceText: snapshot.hasPrice ? format.price(snapshot.price) : "—",
            changePercentText: format.signedPercent(snapshot.priceChangePercent),
            changeAmountText: format.signedUsd(snapshot.priceChangeAmount),
            isChangePositive: snapshot.priceChangePercent == 0 ? nil : snapshot.priceChangePercent > 0,
            volumeText: format.usdShort(snapshot.volume24h),
            openInterestText: format.usdShort(snapshot.openInterest),
            fundingText: snapshot.fundingRatePercent.map { format.funding(percent: $0) },
            about: snapshot.about ?? TKLocales.Perps.Asset.aboutPlaceholder(snapshot.symbol),
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
        isLimitOrderBusy: Bool
    ) -> Actions {
        let canOpen = isOpenAllowed(snapshot: snapshot, flags: flags, isAccountActive: isAccountActive)
        let canClose = isCloseAllowed(flags: flags)
        let canResize = canOpen || canClose
        switch lifecycle {
        case .flat:
            if let restingLimitOrder {
                let enabled = flags.canCancelOrders && !isLimitOrderBusy
                return .editCancelLimitOrder(
                    orderIndex: restingLimitOrder.orderIndex,
                    editEnabled: enabled && !restingLimitOrder.isBelowMarketMinimum,
                    cancelEnabled: enabled
                )
            }
            return .longShort(enabled: canOpen)
        case .opening:
            return .longShort(enabled: false)
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
        let hidden = format.hiddenBalanceText
        return Position(
            valueText: format.balance(summary.equityUsd),
            isPending: isPending,
            pnlText: format.signedBalance(summary.unrealizedPnlUsd),
            pnlPercentText: hidden == nil ? summary.roiPercent.map { format.signedPercent($0) } : nil,
            isPnlPositive: hidden == nil && summary.unrealizedPnlUsd != 0 ? summary.unrealizedPnlUsd > 0 : nil,
            isLong: summary.side == .long,
            sideText: sideText,
            leverageText: summary.leverage.map { format.leverage($0).uppercased() },
            sizeUsdText: format.balance(summary.notionalUsd),
            sizeTokenText: hidden ?? format.token(summary.baseSize, symbol: summary.symbol, decimals: sizeDecimals),
            liquidationText: format.price(summary.liquidationPrice),
            liquidationDistanceText: distanceText,
            markText: format.price(markPrice),
            entryText: format.price(summary.entryPrice),
            fundingText: summary.fundingPaidUsd.map { format.signedBalance($0) } ?? "—"
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
        var isPositive: Bool?
        if let position, position.baseSize > 0 {
            let projection = position.triggerProjection(triggerPrice: order.triggerPrice, baseAmount: position.baseSize)
            isPositive = projection.pnlUsd == 0 ? nil : projection.pnlUsd > 0
            valueText = format.signedBalance(projection.pnlUsd)
            let roePercent = order.projectedROIPercent ?? projection.roePercent.map(PerpsTriggerROI.cutToHundredths)
            percentText = format.hiddenBalanceText == nil ? roePercent.map { format.signedPercent($0) } : nil
        }
        let kindText = order.kind == .takeProfit ? TKLocales.Perps.OpenPosition.tp : TKLocales.Perps.OpenPosition.sl
        return TriggerOrder(
            id: "\(order.orderIndex)",
            actionText: action,
            kindText: kindText,
            isTakeProfit: order.kind == .takeProfit,
            priceText: format.price(order.triggerPrice),
            valueText: valueText,
            percentText: percentText,
            isPositive: isPositive
        )
    }

    nonisolated static func makeLimitOrder(_ order: PerpsLimitOrderSummary, format: PerpsFormatting) -> LimitOrder {
        let autoClose = PerpsAutoClose(triggerOrders: order.autoCloseLegs)
        return LimitOrder(
            id: "limit-\(order.orderIndex)",
            orderIndex: order.orderIndex,
            limitPriceText: format.price(order.limitPrice),
            captionText: order.expiresAtSeconds > 0
                ? TKLocales.Perps.Asset.limitPriceExpires(format.dayMonth(Date(timeIntervalSince1970: TimeInterval(order.expiresAtSeconds))))
                : TKLocales.Perps.Asset.limitPrice,
            sideText: (order.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).uppercased(),
            isLong: order.side == .long,
            takeProfitText: autoClose?.takeProfit.map { format.price($0.triggerPrice) },
            stopLossText: autoClose?.stopLoss.map { format.price($0.triggerPrice) }
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
            amountText: event.isClosing ? event.pnl.map(format.signedBalance) : event.margin.map(format.balance),
            amountStyle: event.isClosing && format.hiddenBalanceText == nil
                ? ((event.pnl ?? 0) >= 0 ? .positive : .negative)
                : .primary
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
        let amount = format.balance(amountUsd)
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

    /// The modify replaces the whole order, so its size is shown with the new price before it is signed,
    /// together with the TP/SL the new price passes, which Confirm cancels first.
    nonisolated static func limitOrderChangeReviewText(
        _ review: PerpsLimitOrderChangeReview,
        symbol: String,
        sizeDecimals: Int,
        removedLegs: [PerpsTriggerOrderSummary],
        format: PerpsFormatting
    ) -> (title: String, message: String) {
        let size = format.token(review.baseAmount, symbol: symbol, decimals: sizeDecimals)
        let price = "\(format.price(review.order.limitPrice)) → \(format.price(review.limitPrice ?? review.order.limitPrice))"
        let removals = removedLegs.map {
            $0.kind == .takeProfit ? TKLocales.Perps.SetLimitPrice.takeProfitRemoved : TKLocales.Perps.SetLimitPrice.stopLossRemoved
        }
        return (
            title: toastPosition(symbol: symbol, side: review.order.side),
            message: (["\(TKLocales.Perps.Confirm.size) \(size)", "\(TKLocales.Perps.Order.price) \(price)"] + removals).joined(separator: "\n")
        )
    }

    nonisolated static func openingToastText(_ descriptor: PerpsOpeningDescriptor, format: PerpsFormatting) -> String {
        let verb = descriptor.isLimit ? TKLocales.Perps.Toast.placing : TKLocales.Perps.Toast.opening
        let position = toastPosition(symbol: descriptor.symbol, side: descriptor.side)
        let margin = format.balance(descriptor.marginUsd)
        let leverage = format.leverage(descriptor.leverage)
        return "\(verb) \(position): \(margin) · \(leverage)"
    }

    nonisolated static func toastPosition(symbol: String, side: PerpsTradeSide) -> String {
        side == .long ? TKLocales.Perps.Toast.long(symbol) : TKLocales.Perps.Toast.short(symbol)
    }

    /// Design pill copy for close: "Closing BTC long · 27⨯" / "Closed BTC long · 27⨯".
    nonisolated static func closeToastText(
        verb: String,
        symbol: String,
        side: PerpsTradeSide,
        leverage: Double?,
        format: PerpsFormatting
    ) -> String {
        let leverageText = leverage.map { " · \(format.leverage($0))" } ?? ""
        return "\(verb) \(toastPosition(symbol: symbol, side: side))\(leverageText)"
    }
}

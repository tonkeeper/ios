import Combine
import Foundation
import PerpsModels
import TKLocalize
import TKLogging

struct PerpsConfirmContext {
    let intent: PerpsOpenMarketIntent
    let sizeDecimals: Int
    let priceDecimals: Int
    var review: PerpsOpenOrderReview

    func autoCloseSheetContext(referencePrice: Double, roiInput: PerpsAutoCloseROIInput) -> PerpsAutoCloseSheetContext {
        let referencePrice = intent.limitPrice ?? referencePrice
        let entryPrice = review.entryPrice ?? referencePrice
        let base = PerpsAutoCloseBase(
            side: intent.side, entryPrice: entryPrice, leverage: intent.leverage, priceDecimals: priceDecimals
        )
        return PerpsAutoCloseSheetContext(
            marketId: intent.marketId,
            side: intent.side,
            entryPrice: entryPrice,
            referencePrice: referencePrice,
            leverage: intent.leverage,
            baseSize: review.baseSize,
            liquidationPrice: review.liquidationPrice,
            priceDecimals: priceDecimals,
            draft: roiInput.resolving(intent.autoClose, on: base),
            roiInput: roiInput,
            livePriceMarketId: intent.limitPrice == nil ? intent.marketId : nil
        )
    }

    /// A nil `roiInput` keeps the ROI typed for the legs that remain.
    func replacingAutoClose(_ autoClose: PerpsAutoClose?, roiInput: PerpsAutoCloseROIInput? = nil) -> PerpsConfirmContext {
        let takeProfitROI = roiInput.map { $0.takeProfit?.value } ?? intent.takeProfitROIPercent
        let stopLossROI = roiInput.map { $0.stopLoss?.value } ?? intent.stopLossROIPercent
        return PerpsConfirmContext(
            intent: PerpsOpenMarketIntent(
                marketId: intent.marketId,
                side: intent.side,
                marginUsd: intent.marginUsd,
                leverage: intent.leverage,
                maxSlippage: intent.maxSlippage,
                autoClose: autoClose,
                limitPrice: intent.limitPrice,
                takeProfitROIPercent: autoClose?.takeProfit == nil ? nil : takeProfitROI,
                stopLossROIPercent: autoClose?.stopLoss == nil ? nil : stopLossROI
            ),
            sizeDecimals: sizeDecimals,
            priceDecimals: priceDecimals,
            review: review
        )
    }
}

struct PerpsCloseConfirmContext {
    let marketId: Int64
    let sizeDecimals: Int
    var review: PerpsCloseReview
}

struct PerpsMarginChangeConfirmContext {
    let marketId: Int64
    var review: PerpsMarginChangeReview
}

@MainActor
final class PerpsTradeConfirmViewModel: ObservableObject, PerpsTradeConfirmViewModeling {
    typealias Tone = PerpsTradeConfirmTone
    typealias ValuePart = PerpsTradeConfirmValuePart
    typealias Row = PerpsTradeConfirmRow

    @Published private(set) var rows: [Row] = []
    @Published private(set) var isConfirmationEnabled = true
    @Published private(set) var isProcessing = false

    let titleText: String
    let iconLetter: String
    let iconURL: URL?

    var onConfirm: (() -> Void)?
    var onSwipeBegan: (() -> Void)?
    var onSwipeAbandoned: (() -> Void)?
    var onClose: (() -> Void)?
    var onBack: (() -> Void)?
    var onEditAutoClose: (@MainActor () async -> Void)?
    var onAutoCloseStale: ((PerpsAutoCloseValidation.ConfirmStaleKind) -> Void)?
    var onRefreshReview: (@MainActor () async -> Void)?
    var onOpenLoyalty: (() -> Void)?
    var loyaltyReward: (@MainActor (_ volumeUsd: Double) async throws -> String?)? {
        didSet { refreshLoyaltyReward() }
    }

    var reviewLifetime: TimeInterval = 1
    var loyaltyRewardInterval: TimeInterval = 3

    var openConfirmContext: PerpsConfirmContext? {
        guard case let .open(context) = subject else { return nil }
        return context
    }

    private var subject: Subject
    private let priceFeed: PerpsMarketPriceFeed?
    private var sizeChangeSessionCancellable: AnyCancellable?
    private var markPrice: Double?
    private var reviewRefresh = ReviewRefresh.idle(since: Date())
    private(set) var awaitsReview = false
    private var isOnScreen = false
    private var autoCloseEditTask: Task<Void, Never>?
    private var announcedAutoCloseStale: PerpsAutoCloseValidation.ConfirmStaleKind?
    private var loyaltyRewardShown: (volume: Double, ohms: String)?
    private var loyaltyRewardVolume: Double?
    private var loyaltyRewardAskedAt: Date?
    private var loyaltyRewardTask: Task<Void, Never>?
    let format: PerpsFormatting

    convenience init(
        context: PerpsConfirmContext,
        format: PerpsFormatting,
        iconURL: URL? = nil,
        marketsStore: (any PerpsMarketsStoring)? = nil
    ) {
        self.init(subject: .open(context), format: format, iconURL: iconURL, marketsStore: marketsStore)
    }

    convenience init(
        closeContext: PerpsCloseConfirmContext,
        format: PerpsFormatting,
        iconURL: URL? = nil,
        marketsStore: (any PerpsMarketsStoring)? = nil
    ) {
        self.init(subject: .close(closeContext), format: format, iconURL: iconURL, marketsStore: marketsStore)
    }

    convenience init(
        marginChangeContext: PerpsMarginChangeConfirmContext,
        format: PerpsFormatting,
        iconURL: URL? = nil,
        marketsStore: (any PerpsMarketsStoring)? = nil
    ) {
        self.init(subject: .marginChange(marginChangeContext), format: format, iconURL: iconURL, marketsStore: marketsStore)
    }

    convenience init?(
        sizeChangeSession: PerpsSizeChangeSession,
        sizeDecimals: Int,
        format: PerpsFormatting,
        iconURL: URL? = nil,
        marketsStore: (any PerpsMarketsStoring)? = nil
    ) {
        guard let confirmationState = sizeChangeSession.confirmationState else { return nil }
        self.init(
            subject: .sizeChange(confirmationState, sizeDecimals: sizeDecimals),
            format: format,
            iconURL: iconURL,
            marketsStore: marketsStore
        )
        sizeChangeSessionCancellable = sizeChangeSession.$confirmationState
            .dropFirst()
            .sink { [weak self] state in
                self?.applySizeChangeConfirmationState(state)
            }
    }

    private init(
        subject: Subject,
        format: PerpsFormatting,
        iconURL: URL?,
        marketsStore: (any PerpsMarketsStoring)?
    ) {
        self.format = format
        self.subject = subject
        self.iconURL = iconURL
        priceFeed = marketsStore.map { PerpsMarketPriceFeed(marketId: subject.marketId, store: $0) }
        titleText = subject.titleText
        iconLetter = subject.iconLetter
        isConfirmationEnabled = subject.isInteractionEnabled
        refreshRows()
        priceFeed?.observe(self) { $0.applyLivePrice() }
    }

    // MARK: - Intent

    func swipeBegan() {
        onSwipeBegan?()
    }

    func swipeAbandoned() {
        onSwipeAbandoned?()
    }

    func confirm() {
        guard isConfirmationEnabled, autoCloseEditTask == nil else { return }
        isConfirmationEnabled = false
        isProcessing = true
        PerpsOperationLog.event("ui_confirm", outcome: "started", fields: ["flow": "trade", "market_id": String(subject.marketId), "action": subject.action])
        onConfirm?()
    }

    func restoreConfirmation() {
        isProcessing = false
        isConfirmationEnabled = true
    }

    /// For an open shown on figures that may no longer hold: the swipe waits for a review read for
    /// this screen, and the first read starts on appear instead of a second later.
    func awaitReview() {
        guard case .open = subject else { return }
        awaitsReview = true
        isConfirmationEnabled = false
        isProcessing = true
        reviewRefresh = .idle(since: .distantPast)
        loyaltyRewardTask?.cancel()
        loyaltyRewardVolume = nil
    }

    func close() {
        leave()
        onClose?()
    }

    func back() {
        leave()
        onBack?()
    }

    func openLoyalty() {
        onOpenLoyalty?()
    }

    func editAutoClose() {
        guard isConfirmationEnabled, autoCloseEditTask == nil, let onEditAutoClose else { return }
        autoCloseEditTask = Task { [weak self] in
            defer {
                if !Task.isCancelled { self?.autoCloseEditTask = nil }
            }
            await onEditAutoClose()
        }
    }

    func autoCloseEditingContext(
        preview: (PerpsOpenMarketIntent) async -> Result<PerpsOpenOrderReview, PerpsTradingError>
    ) async -> PerpsConfirmContext? {
        guard var context = openConfirmContext else { return nil }
        if case let .success(review) = await preview(context.replacingAutoClose(nil).intent) {
            context.review = review
        }
        guard !Task.isCancelled, isConfirmationEnabled, openConfirmContext?.intent == context.intent else { return nil }
        return context
    }

    private func cancelAutoCloseEdit() {
        autoCloseEditTask?.cancel()
        autoCloseEditTask = nil
    }

    /// A screen the user left waits for no figures of its own, so a read that fails after that
    /// cannot end whatever flow is open by then.
    private func leave() {
        awaitsReview = false
        cancelAutoCloseEdit()
    }

    func onAppear() {
        isOnScreen = true
        priceFeed?.subscribe()
        applyLivePrice()
    }

    func onDisappear() {
        isOnScreen = false
        cancelAutoCloseEdit()
        priceFeed?.unsubscribe()
    }

    func updateOpenAutoClose(
        _ autoClose: PerpsAutoClose?,
        roiInput: PerpsAutoCloseROIInput? = nil,
        review: PerpsOpenOrderReview? = nil
    ) {
        guard case var .open(context) = subject else { return }
        if let review { context.review = review }
        subject = .open(context.replacingAutoClose(autoClose, roiInput: roiInput))
        refreshRows()
    }

    func updateOpenReview(_ review: PerpsOpenOrderReview, for intent: PerpsOpenMarketIntent) {
        guard isConfirmationEnabled || awaitsReview, case var .open(context) = subject, context.intent == intent else { return }
        context.review = review
        subject = .open(context)
        if awaitsReview {
            awaitsReview = false
            restoreConfirmation()
        }
        refreshRows()
    }

    func updateCloseReview(_ review: PerpsCloseReview) {
        guard isConfirmationEnabled, case var .close(context) = subject else { return }
        context.review = review
        subject = .close(context)
        refreshRows()
    }

    func updateMarginChangeReview(_ review: PerpsMarginChangeReview) {
        guard isConfirmationEnabled, case var .marginChange(context) = subject else { return }
        context.review = review
        subject = .marginChange(context)
        refreshRows()
    }

    // MARK: - Live price

    private func applyLivePrice() {
        guard let priceFeed else { return }
        markPrice = priceFeed.price
        refreshRows()
        refreshReviewIfStale()
    }

    private func refreshReviewIfStale() {
        guard isOnScreen,
              isConfirmationEnabled || awaitsReview,
              case let .idle(since) = reviewRefresh,
              Date().timeIntervalSince(since) >= reviewLifetime,
              let onRefreshReview
        else { return }
        reviewRefresh = .running
        Task { [weak self] in
            await onRefreshReview()
            self?.reviewRefresh = .idle(since: Date())
        }
    }

    private func applySizeChangeConfirmationState(_ state: PerpsSizeChangeSession.ConfirmationState?) {
        guard case let .sizeChange(previous, sizeDecimals) = subject else { return }
        subject = .sizeChange(state ?? previous, sizeDecimals: sizeDecimals)
        isConfirmationEnabled = state?.isInteractionEnabled ?? false
        if isConfirmationEnabled { isProcessing = false }
        refreshRows()
    }

    // MARK: - Rows

    private func refreshRows() {
        var rows: [Row]
        switch subject {
        case let .open(context):
            rows = Self.makeOpenRows(
                context: context,
                referencePrice: referencePrice(fallback: context.review.entryPrice),
                format: format
            )
        case let .close(context):
            rows = Self.makeCloseRows(review: context.review, sizeDecimals: context.sizeDecimals, format: format)
        case let .sizeChange(state, sizeDecimals):
            let review = state.prepared.review
            rows = Self.makeSizeChangeRows(
                review: review,
                autoClose: state.autoClose,
                sizeDecimals: sizeDecimals,
                referencePrice: referencePrice(fallback: review.entryPrice.new),
                format: format
            )
        case let .marginChange(context):
            rows = Self.makeMarginChangeRows(review: context.review, format: format)
        }
        if let loyaltyRewardShown, subject.loyaltyVolumeUsd != nil {
            rows.append(Row(
                id: .loyaltyReward,
                title: TKLocales.Loyalty.resistanceReward,
                value: TKLocales.Loyalty.rewardValue(loyaltyRewardShown.ohms),
                subValue: nil
            ))
        }
        self.rows = rows
        announceAutoCloseStaleIfNeeded()
        refreshLoyaltyReward()
    }

    private func refreshLoyaltyReward() {
        guard !awaitsReview, let loyaltyReward, let volume = subject.loyaltyVolumeUsd, volume != loyaltyRewardVolume else { return }
        loyaltyRewardVolume = volume
        loyaltyRewardTask?.cancel()
        let delay = loyaltyRewardAskedAt.map { max(0, loyaltyRewardInterval - Date().timeIntervalSince($0)) } ?? 0
        loyaltyRewardTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            self?.loyaltyRewardAskedAt = Date()
            let shown: (volume: Double, ohms: String)?
            do {
                shown = try await loyaltyReward(volume).map { (volume, $0) }
            } catch {
                guard let self, !Task.isCancelled else { return }
                loyaltyRewardVolume = nil
                if loyaltyRewardShown?.volume != volume {
                    loyaltyRewardShown = nil
                }
                refreshRows()
                return
            }
            guard let self, !Task.isCancelled else { return }
            let changed = loyaltyRewardShown?.ohms != shown?.ohms
            loyaltyRewardShown = shown
            if changed {
                refreshRows()
            }
        }
    }

    private func announceAutoCloseStaleIfNeeded() {
        guard isOnScreen, isConfirmationEnabled else { return }
        let kind = autoCloseStaleKind
        guard kind != announcedAutoCloseStale else { return }
        announcedAutoCloseStale = kind
        if let kind {
            onAutoCloseStale?(kind)
        }
    }

    private var autoCloseStaleKind: PerpsAutoCloseValidation.ConfirmStaleKind? {
        switch subject {
        case let .open(context):
            return context.intent.autoClose.flatMap {
                PerpsAutoCloseValidation.confirmStaleKind(
                    side: context.intent.side,
                    referencePrice: referencePrice(fallback: context.review.entryPrice),
                    liquidationPrice: context.review.liquidationPrice,
                    autoClose: $0
                )
            }
        case let .sizeChange(state, _):
            guard case .replace = state.prepared.intent.autoCloseUpdate else { return nil }
            return state.autoClose.flatMap {
                PerpsAutoCloseValidation.confirmStaleKind(
                    side: state.prepared.review.side,
                    referencePrice: referencePrice(fallback: state.prepared.review.entryPrice.new),
                    liquidationPrice: state.prepared.review.liquidationPrice?.new,
                    autoClose: $0
                )
            }
        case .close, .marginChange:
            return nil
        }
    }

    private func referencePrice(fallback: Double?) -> Double {
        subject.limitPrice ?? markPrice ?? fallback ?? 0
    }
}

private extension PerpsTradeConfirmViewModel {
    enum ReviewRefresh {
        case idle(since: Date)
        case running
    }

    /// What is being confirmed. The four screens differ only in this.
    enum Subject {
        case open(PerpsConfirmContext)
        case close(PerpsCloseConfirmContext)
        case sizeChange(PerpsSizeChangeSession.ConfirmationState, sizeDecimals: Int)
        case marginChange(PerpsMarginChangeConfirmContext)

        var marketId: Int64 {
            switch self {
            case let .open(context): context.intent.marketId
            case let .close(context): context.marketId
            case let .sizeChange(state, _): state.prepared.marketId
            case let .marginChange(context): context.marketId
            }
        }

        var action: String {
            switch self {
            case .open: "open"
            case .close: "close"
            case .sizeChange: "size_change"
            case .marginChange: "margin_change"
            }
        }

        var limitPrice: Double? {
            guard case let .open(context) = self else { return nil }
            return context.intent.limitPrice
        }

        var loyaltyVolumeUsd: Double? {
            let notionalUsd: Double? = switch self {
            case let .open(context): context.review.notionalUsd
            case let .close(context): context.review.notionalUsd
            case .sizeChange, .marginChange: nil
            }
            return notionalUsd.map(Self.cents)
        }

        private static func cents(_ usd: Double) -> Double {
            var value = Decimal(string: String(usd)) ?? Decimal(usd)
            var cents = Decimal()
            NSDecimalRound(&cents, &value, 2, .down)
            return NSDecimalNumber(decimal: cents).doubleValue
        }

        var isInteractionEnabled: Bool {
            switch self {
            case let .sizeChange(state, _): state.isInteractionEnabled
            case .open, .close, .marginChange: true
            }
        }

        var iconLetter: String {
            symbol.prefix(1).uppercased()
        }

        var titleText: String {
            let isLong = side == .long
            switch self {
            case .open:
                return isLong ? TKLocales.Perps.Confirm.openLong(symbol) : TKLocales.Perps.Confirm.openShort(symbol)
            case .close:
                return isLong ? TKLocales.Perps.Confirm.closeLong(symbol) : TKLocales.Perps.Confirm.closeShort(symbol)
            case let .sizeChange(state, _):
                return PerpsSizeChangeViewModel.titleText(
                    direction: state.prepared.review.direction,
                    side: side,
                    symbol: symbol
                )
            case let .marginChange(context):
                switch (context.review.direction, side) {
                case (.add, .long): return TKLocales.Perps.AdjustMargin.addConfirmTitleLong(symbol)
                case (.add, .short): return TKLocales.Perps.AdjustMargin.addConfirmTitleShort(symbol)
                case (.reduce, .long): return TKLocales.Perps.AdjustMargin.reduceConfirmTitleLong(symbol)
                case (.reduce, .short): return TKLocales.Perps.AdjustMargin.reduceConfirmTitleShort(symbol)
                }
            }
        }

        private var symbol: String {
            switch self {
            case let .open(context): context.review.symbol
            case let .close(context): context.review.symbol
            case let .sizeChange(state, _): state.prepared.review.symbol
            case let .marginChange(context): context.review.symbol
            }
        }

        private var side: PerpsTradeSide {
            switch self {
            case let .open(context): context.intent.side
            case let .close(context): context.review.side
            case let .sizeChange(state, _): state.prepared.review.side
            case let .marginChange(context): context.review.side
            }
        }
    }
}

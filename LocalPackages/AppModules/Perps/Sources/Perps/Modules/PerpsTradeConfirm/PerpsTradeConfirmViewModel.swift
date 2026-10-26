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

    func replacingAutoClose(_ autoClose: PerpsAutoClose?) -> PerpsConfirmContext {
        PerpsConfirmContext(
            intent: PerpsOpenMarketIntent(
                marketId: intent.marketId,
                side: intent.side,
                marginUsd: intent.marginUsd,
                leverage: intent.leverage,
                maxSlippage: intent.maxSlippage,
                autoClose: autoClose,
                limitPrice: intent.limitPrice
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
    var onClose: (() -> Void)?
    var onBack: (() -> Void)?
    var onEditAutoClose: (@MainActor () async -> Void)?
    var onAutoCloseStale: ((PerpsAutoCloseValidation.ConfirmStaleKind) -> Void)?
    var onRefreshReview: (@MainActor () async -> Void)?
    var reviewLifetime: TimeInterval = 5

    var openConfirmContext: PerpsConfirmContext? {
        guard case let .open(context) = subject else { return nil }
        return context
    }

    private var subject: Subject
    private let priceFeed: PerpsMarketPriceFeed?
    private var sizeChangeSessionCancellable: AnyCancellable?
    private var markPrice: Double?
    private var reviewRefresh = ReviewRefresh.idle(since: Date())
    private var isOnScreen = false
    private var autoCloseEditTask: Task<Void, Never>?
    private var announcedAutoCloseStale: PerpsAutoCloseValidation.ConfirmStaleKind?
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

    func confirm() {
        guard isConfirmationEnabled, autoCloseEditTask == nil else { return }
        isConfirmationEnabled = false
        isProcessing = true
        let shown = rows
            .map { "\($0.title)=\($0.value)\($0.subValue.map { " (\($0))" } ?? "")" }
            .joined(separator: "; ")
        Log.perps.i("confirm \(titleText): \(shown)")
        onConfirm?()
    }

    func restoreConfirmation() {
        isProcessing = false
        isConfirmationEnabled = true
    }

    func close() {
        cancelAutoCloseEdit()
        onClose?()
    }

    func back() {
        cancelAutoCloseEdit()
        onBack?()
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

    func updateOpenAutoClose(_ autoClose: PerpsAutoClose?, review: PerpsOpenOrderReview? = nil) {
        guard case var .open(context) = subject else { return }
        if let review { context.review = review }
        subject = .open(context.replacingAutoClose(autoClose))
        refreshRows()
    }

    func updateOpenReview(_ review: PerpsOpenOrderReview, for intent: PerpsOpenMarketIntent) {
        guard isConfirmationEnabled, case var .open(context) = subject, context.intent == intent else { return }
        context.review = review
        subject = .open(context)
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
              isConfirmationEnabled,
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
        announceAutoCloseStaleIfNeeded()
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

        var limitPrice: Double? {
            guard case let .open(context) = self else { return nil }
            return context.intent.limitPrice
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
            switch self {
            case .open:
                "\(TKLocales.Perps.Confirm.open) \(position)"
            case .close:
                "\(TKLocales.Perps.Confirm.close) \(position)"
            case let .sizeChange(state, _):
                state.prepared.review.direction == .add
                    ? TKLocales.Perps.EditPosition.addTitle(position)
                    : TKLocales.Perps.EditPosition.reduceTitle(position)
            case let .marginChange(context):
                context.review.direction == .add
                    ? TKLocales.Perps.AdjustMargin.addConfirmTitle(position)
                    : TKLocales.Perps.AdjustMargin.reduceConfirmTitle(position)
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

        private var position: String {
            let sideText = side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short
            return "\(sideText) \(symbol)"
        }
    }
}

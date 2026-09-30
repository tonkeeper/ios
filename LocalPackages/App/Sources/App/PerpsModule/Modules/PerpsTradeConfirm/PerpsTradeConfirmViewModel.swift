import Combine
import Foundation
import KeeperCore
import TKLocalize

struct PerpsConfirmContext {
    let intent: PerpsOpenMarketIntent
    let sizeDecimals: Int
    let priceDecimals: Int
    let review: PerpsOpenOrderReview

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
    let sizeDecimals: Int
    let review: PerpsCloseReview
}

struct PerpsMarginChangeConfirmContext {
    let review: PerpsMarginChangeReview
}

@MainActor
final class PerpsTradeConfirmViewModel: ObservableObject {
    enum Tone: Equatable {
        case neutral, positive, negative, tertiary
    }

    struct ValuePart: Equatable {
        let text: String
        let tone: Tone
    }

    struct Row: Identifiable {
        enum Kind: Hashable {
            case youPay, entry, leverage, liquidation, size, fee, autoClose
            case position, pnl, youReceive
            case youClose
        }

        let id: Kind
        let title: String
        let value: String
        let valueParts: [ValuePart]?
        let subValue: String?
        let tone: Tone
        let showsChevron: Bool

        init(
            id: Kind,
            title: String,
            value: String,
            valueParts: [ValuePart]? = nil,
            subValue: String?,
            tone: Tone = .neutral,
            showsChevron: Bool = false
        ) {
            self.id = id
            self.title = title
            self.value = value
            self.valueParts = valueParts
            self.subValue = subValue
            self.tone = tone
            self.showsChevron = showsChevron
        }
    }

    @Published private(set) var rows: [Row] = []
    @Published private(set) var isConfirmationEnabled = true

    let titleText: String
    let iconLetter: String
    let iconURL: URL?

    var onConfirm: (() -> Void)?
    var onClose: (() -> Void)?
    var onBack: (() -> Void)?
    var onEditAutoClose: (() -> Void)?

    var openConfirmContext: PerpsConfirmContext? {
        guard case let .open(context) = subject else { return nil }
        return context
    }

    private var subject: Subject
    private let marketsStore: PerpsMarketsStore?
    private let priceInterest: PerpsMarketsPriceInterest?
    private var sizeChangeSessionCancellable: AnyCancellable?
    private var markPrice: Double?

    convenience init(context: PerpsConfirmContext, iconURL: URL? = nil, marketsStore: PerpsMarketsStore? = nil) {
        self.init(subject: .open(context), iconURL: iconURL, marketsStore: marketsStore)
    }

    convenience init(closeContext: PerpsCloseConfirmContext, iconURL: URL? = nil) {
        self.init(subject: .close(closeContext), iconURL: iconURL, marketsStore: nil)
    }

    convenience init(marginChangeContext: PerpsMarginChangeConfirmContext, iconURL: URL? = nil) {
        self.init(subject: .marginChange(marginChangeContext), iconURL: iconURL, marketsStore: nil)
    }

    convenience init?(
        sizeChangeSession: PerpsSizeChangeSession,
        sizeDecimals: Int,
        iconURL: URL? = nil,
        marketsStore: PerpsMarketsStore? = nil
    ) {
        guard let confirmationState = sizeChangeSession.confirmationState else { return nil }
        self.init(
            subject: .sizeChange(confirmationState, sizeDecimals: sizeDecimals),
            iconURL: iconURL,
            marketsStore: marketsStore
        )
        sizeChangeSessionCancellable = sizeChangeSession.$confirmationState
            .dropFirst()
            .sink { [weak self] state in
                self?.applySizeChangeConfirmationState(state)
            }
    }

    private init(subject: Subject, iconURL: URL?, marketsStore: PerpsMarketsStore?) {
        self.subject = subject
        self.iconURL = iconURL
        self.marketsStore = marketsStore
        priceInterest = marketsStore?.makePriceInterest()
        titleText = subject.titleText
        iconLetter = subject.iconLetter
        isConfirmationEnabled = subject.isInteractionEnabled
        refreshRows()
        observeLivePrices()
    }

    // MARK: - Intent

    func confirm() {
        guard isConfirmationEnabled else { return }
        isConfirmationEnabled = false
        onConfirm?()
    }

    func restoreConfirmation() {
        isConfirmationEnabled = true
    }

    func close() {
        onClose?()
    }

    func back() {
        onBack?()
    }

    func editAutoClose() {
        guard isConfirmationEnabled else { return }
        onEditAutoClose?()
    }

    func onAppear() {
        guard let priceInterest, let marketId = subject.marketId else { return }
        priceInterest.set(marketIds: [marketId])
        applyMarketsStoreState()
    }

    func onDisappear() {
        priceInterest?.clear()
    }

    func updateOpenAutoClose(_ autoClose: PerpsAutoClose?) {
        guard case let .open(context) = subject else { return }
        subject = .open(context.replacingAutoClose(autoClose))
        refreshRows()
    }

    // MARK: - Live price

    private func observeLivePrices() {
        guard let marketsStore, subject.marketId != nil else { return }
        marketsStore.addObserver(self) { observer, _ in
            Task { @MainActor in
                observer.applyMarketsStoreState()
            }
        }
    }

    private func applyMarketsStoreState() {
        guard let marketsStore, let marketId = subject.marketId else { return }
        markPrice = marketsStore.getState().price(marketId: marketId)
        refreshRows()
    }

    private func applySizeChangeConfirmationState(_ state: PerpsSizeChangeSession.ConfirmationState?) {
        guard case let .sizeChange(previous, sizeDecimals) = subject else { return }
        subject = .sizeChange(state ?? previous, sizeDecimals: sizeDecimals)
        isConfirmationEnabled = state?.isInteractionEnabled ?? false
        refreshRows()
    }

    // MARK: - Rows

    private func refreshRows() {
        switch subject {
        case let .open(context):
            rows = Self.makeOpenRows(
                context: context,
                referencePrice: referencePrice(fallback: context.review.entryPrice)
            )
        case let .close(context):
            rows = Self.makeCloseRows(review: context.review, sizeDecimals: context.sizeDecimals)
        case let .sizeChange(state, sizeDecimals):
            let review = state.prepared.review
            rows = Self.makeSizeChangeRows(
                review: review,
                autoClose: state.autoClose,
                sizeDecimals: sizeDecimals,
                referencePrice: referencePrice(fallback: review.entryPrice.new)
            )
        case let .marginChange(context):
            rows = Self.makeMarginChangeRows(review: context.review)
        }
    }

    private func referencePrice(fallback: Double?) -> Double {
        subject.limitPrice ?? markPrice ?? fallback ?? 0
    }
}

private extension PerpsTradeConfirmViewModel {
    /// What is being confirmed. The four screens differ only in this, and only
    /// open and size change follow a live price and rebuild their rows.
    enum Subject {
        case open(PerpsConfirmContext)
        case close(PerpsCloseConfirmContext)
        case sizeChange(PerpsSizeChangeSession.ConfirmationState, sizeDecimals: Int)
        case marginChange(PerpsMarginChangeConfirmContext)

        var marketId: Int64? {
            switch self {
            case let .open(context): context.intent.marketId
            case let .sizeChange(state, _): state.prepared.marketId
            case .close, .marginChange: nil
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

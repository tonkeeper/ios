import Combine
import Foundation
import KeeperCore
import TKLocalize

struct PerpsConfirmContext {
    let intent: PerpsOpenMarketIntent
    let sizeDecimals: Int
    let review: PerpsOpenOrderReview
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

    @Published private(set) var rows: [Row]

    let titleText: String
    let iconLetter: String
    let iconURL: URL?

    var onConfirm: (() -> Void)?
    var onClose: (() -> Void)?
    var onBack: (() -> Void)?
    var onEditAutoClose: (() -> Void)?

    @Published private(set) var isConfirmationEnabled = true

    private(set) var openConfirmContext: PerpsConfirmContext?

    private let marketsStore: PerpsMarketsStore?
    private let priceInterest: PerpsMarketsPriceInterest?
    private let marketId: Int64?
    private let limitPrice: Double?
    private let sizeChangeSizeDecimals: Int?
    private var sizeChangeConfirmationState: PerpsSizeChangeSession.ConfirmationState?
    private var sizeChangeSessionCancellable: AnyCancellable?
    private var markPrice: Double?

    init(context: PerpsConfirmContext, iconURL: URL? = nil, marketsStore: PerpsMarketsStore? = nil) {
        openConfirmContext = context
        self.iconURL = iconURL
        self.marketsStore = marketsStore
        priceInterest = marketsStore?.makePriceInterest()
        marketId = context.intent.marketId
        limitPrice = context.intent.limitPrice
        sizeChangeSizeDecimals = nil
        sizeChangeConfirmationState = nil
        titleText = Self.title(verb: TKLocales.Perps.Confirm.open, side: context.intent.side, symbol: context.review.symbol)
        iconLetter = context.review.symbol.prefix(1).uppercased()
        rows = Self.makeOpenRows(
            context: context,
            referencePrice: Self.referencePrice(
                limitPrice: context.intent.limitPrice,
                markPrice: nil,
                fallback: context.review.entryPrice
            )
        )
        observeLivePrices()
    }

    init(closeContext: PerpsCloseConfirmContext, iconURL: URL? = nil) {
        openConfirmContext = nil
        self.iconURL = iconURL
        marketsStore = nil
        priceInterest = nil
        marketId = nil
        limitPrice = nil
        sizeChangeSizeDecimals = nil
        sizeChangeConfirmationState = nil
        let review = closeContext.review
        titleText = Self.title(verb: TKLocales.Perps.Confirm.close, side: review.side, symbol: review.symbol)
        iconLetter = review.symbol.prefix(1).uppercased()
        rows = Self.makeCloseRows(review: review, sizeDecimals: closeContext.sizeDecimals)
    }

    init?(
        sizeChangeSession: PerpsSizeChangeSession,
        sizeDecimals: Int,
        iconURL: URL? = nil,
        marketsStore: PerpsMarketsStore? = nil
    ) {
        guard let confirmationState = sizeChangeSession.confirmationState else { return nil }
        let prepared = confirmationState.prepared
        openConfirmContext = nil
        self.iconURL = iconURL
        sizeChangeSizeDecimals = sizeDecimals
        sizeChangeConfirmationState = confirmationState
        isConfirmationEnabled = confirmationState.isInteractionEnabled
        self.marketsStore = marketsStore
        priceInterest = marketsStore?.makePriceInterest()
        marketId = prepared.marketId
        limitPrice = nil
        let review = prepared.review
        let sideText = review.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short
        let position = "\(sideText) \(review.symbol)"
        titleText = review.direction == .add
            ? TKLocales.Perps.EditPosition.addTitle(position)
            : TKLocales.Perps.EditPosition.reduceTitle(position)
        iconLetter = review.symbol.prefix(1).uppercased()
        rows = Self.makeSizeChangeRows(
            review: review,
            autoClose: confirmationState.autoClose,
            sizeDecimals: sizeDecimals,
            referencePrice: Self.referencePrice(
                limitPrice: nil,
                markPrice: nil,
                fallback: review.entryPrice.new
            )
        )
        sizeChangeSessionCancellable = sizeChangeSession.$confirmationState
            .dropFirst()
            .sink { [weak self] state in
                self?.applySizeChangeConfirmationState(state)
            }
        observeLivePrices()
    }

    init(marginChangeContext: PerpsMarginChangeConfirmContext, iconURL: URL? = nil) {
        openConfirmContext = nil
        self.iconURL = iconURL
        marketsStore = nil
        priceInterest = nil
        marketId = nil
        limitPrice = nil
        sizeChangeSizeDecimals = nil
        sizeChangeConfirmationState = nil
        let review = marginChangeContext.review
        let sideText = review.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short
        let position = "\(sideText) \(review.symbol)"
        titleText = review.direction == .add
            ? TKLocales.Perps.AdjustMargin.addConfirmTitle(position)
            : TKLocales.Perps.AdjustMargin.reduceConfirmTitle(position)
        iconLetter = review.symbol.prefix(1).uppercased()
        rows = Self.makeMarginChangeRows(review: review)
    }

    // MARK: - Intent

    func confirm() {
        guard isConfirmationEnabled else { return }
        onConfirm?()
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
        guard let priceInterest, let marketId else { return }
        priceInterest.set(marketIds: [marketId])
        applyMarketsStoreState()
    }

    func onDisappear() {
        priceInterest?.clear()
    }

    func updateOpenAutoClose(_ autoClose: PerpsAutoClose?) {
        guard var context = openConfirmContext else { return }
        let intent = PerpsOpenMarketIntent(
            marketId: context.intent.marketId,
            side: context.intent.side,
            marginUsd: context.intent.marginUsd,
            leverage: context.intent.leverage,
            maxSlippage: context.intent.maxSlippage,
            autoClose: autoClose,
            limitPrice: context.intent.limitPrice
        )
        context = PerpsConfirmContext(
            intent: intent,
            sizeDecimals: context.sizeDecimals,
            review: context.review
        )
        openConfirmContext = context
        refreshAutoClosePresentation()
    }

    // MARK: - Rows

    private func observeLivePrices() {
        guard let marketsStore, marketId != nil else { return }
        marketsStore.addObserver(self) { observer, _ in
            Task { @MainActor in
                observer.applyMarketsStoreState()
            }
        }
    }

    private func applyMarketsStoreState() {
        guard let marketsStore, let marketId else { return }
        markPrice = marketsStore.getState().price(marketId: marketId)
        refreshAutoClosePresentation()
    }

    private func refreshAutoClosePresentation() {
        if let context = openConfirmContext {
            rows = Self.makeOpenRows(context: context, referencePrice: currentReferencePrice(fallback: context.review.entryPrice))
            return
        }
        if let sizeChangeConfirmationState,
           let sizeChangeSizeDecimals
        {
            let review = sizeChangeConfirmationState.prepared.review
            rows = Self.makeSizeChangeRows(
                review: review,
                autoClose: sizeChangeConfirmationState.autoClose,
                sizeDecimals: sizeChangeSizeDecimals,
                referencePrice: currentReferencePrice(fallback: review.entryPrice.new)
            )
        }
    }

    private func applySizeChangeConfirmationState(_ state: PerpsSizeChangeSession.ConfirmationState?) {
        sizeChangeConfirmationState = state
        isConfirmationEnabled = state?.isInteractionEnabled ?? false
        refreshAutoClosePresentation()
    }

    private func currentReferencePrice(fallback: Double?) -> Double {
        Self.referencePrice(
            limitPrice: limitPrice,
            markPrice: markPrice,
            fallback: fallback
        )
    }

    private static func referencePrice(limitPrice: Double?, markPrice: Double?, fallback: Double?) -> Double {
        limitPrice ?? markPrice ?? fallback ?? 0
    }

    private static func title(verb: String, side: KeeperCore.PerpsTradeSide, symbol: String) -> String {
        let sideText = side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short
        return "\(verb) \(sideText) \(symbol)"
    }

    private static func makeOpenRows(context: PerpsConfirmContext, referencePrice: Double) -> [Row] {
        let intent = context.intent
        let review = context.review
        let symbol = review.symbol
        var rows: [Row] = []

        rows.append(usdtRow(id: .youPay, title: TKLocales.Perps.Confirm.youPay, usd: review.marginUsd))

        if let entryPrice = review.entryPrice, entryPrice > 0 {
            rows.append(Row(
                id: .entry,
                title: TKLocales.Perps.Confirm.entryPrice,
                value: PerpsFormatting.usd(entryPrice),
                subValue: "≈ 1 \(symbol)"
            ))
        } else {
            rows.append(Row(id: .entry, title: TKLocales.Perps.Confirm.entryPrice, value: TKLocales.Perps.Confirm.unavailable, subValue: nil))
        }

        rows.append(Row(id: .leverage, title: TKLocales.Perps.Confirm.leverage, value: PerpsFormatting.leverage(intent.leverage), subValue: nil))

        rows.append(liquidationRow(review: review))

        rows.append(Row(
            id: .size,
            title: TKLocales.Perps.Confirm.size,
            value: PerpsFormatting.usd(review.notionalUsd),
            subValue: review.baseSize > 0 ? "≈ \(PerpsFormatting.token(review.baseSize, symbol: symbol, decimals: context.sizeDecimals))" : nil
        ))

        rows.append(feeRow(estimatedFeeUsd: review.estimatedFeeUsd))

        if let autoCloseRow = autoCloseRow(
            from: intent.autoClose,
            side: intent.side,
            referencePrice: referencePrice,
            liquidationPrice: review.liquidationPrice
        ) {
            rows.append(autoCloseRow)
        }

        return rows
    }

    private static func makeCloseRows(review: PerpsCloseReview, sizeDecimals: Int) -> [Row] {
        var rows: [Row] = []

        rows.append(usdtRow(id: .position, title: TKLocales.Perps.Confirm.position, usd: review.marginUsd))

        rows.append(Row(
            id: .leverage,
            title: TKLocales.Perps.Confirm.leverage,
            value: review.leverage.map(PerpsFormatting.leverage) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        rows.append(Row(
            id: .size,
            title: TKLocales.Perps.Confirm.size,
            value: PerpsFormatting.usd(review.notionalUsd),
            subValue: review.baseSize > 0 ? "≈ \(PerpsFormatting.token(review.baseSize, symbol: review.symbol, decimals: sizeDecimals))" : nil
        ))

        rows.append(feeRow(estimatedFeeUsd: review.estimatedFeeUsd))

        if let pnl = review.estimatedPnlUsd {
            rows.append(Row(
                id: .pnl,
                title: TKLocales.Perps.Confirm.pnl,
                value: PerpsFormatting.signedUsd(pnl),
                subValue: review.estimatedPnlPercent.map { PerpsFormatting.signedPercent($0) },
                tone: pnl >= 0 ? .positive : .negative
            ))
        } else {
            rows.append(Row(id: .pnl, title: TKLocales.Perps.Confirm.pnl, value: TKLocales.Perps.Confirm.unavailable, subValue: nil))
        }

        rows.append(Row(
            id: .youReceive,
            title: TKLocales.Perps.Confirm.youReceive,
            value: review.estimatedReceiveUsd.map(PerpsFormatting.usd) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: review.estimatedReceiveUsd.map { "≈ \(PerpsFormatting.token($0, symbol: "USDT", decimals: 2))" }
        ))

        return rows
    }

    private static func makeSizeChangeRows(
        review: PerpsSizeChangeReview,
        autoClose: PerpsAutoClose?,
        sizeDecimals: Int,
        referencePrice: Double
    ) -> [Row] {
        var rows: [Row] = []

        rows.append(payOrCloseRow(isAdd: review.direction == .add, usd: review.marginDeltaUsd))

        rows.append(Row(
            id: .entry,
            title: TKLocales.Perps.Confirm.entryPrice,
            value: review.entryPrice.isChanged
                ? "\(PerpsFormatting.usd(review.entryPrice.old)) → \(PerpsFormatting.usd(review.entryPrice.new))"
                : PerpsFormatting.usd(review.entryPrice.old),
            subValue: "≈ 1 \(review.symbol)"
        ))

        rows.append(Row(
            id: .leverage,
            title: TKLocales.Perps.Confirm.leverage,
            value: review.leverage.map(PerpsFormatting.leverage) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        rows.append(Row(
            id: .liquidation,
            title: TKLocales.Perps.Confirm.liquidation,
            value: review.liquidationPrice.map(PerpsFormatting.usd) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: nil
        ))

        let baseDelta = abs(review.baseSize.new - review.baseSize.old)
        rows.append(Row(
            id: .size,
            title: TKLocales.Perps.Confirm.size,
            value: "\(PerpsFormatting.usd(review.notionalUsd.old)) → \(PerpsFormatting.usd(review.notionalUsd.new))",
            subValue: baseDelta > 0
                ? "\(review.direction == .add ? "+" : "−")\(PerpsFormatting.token(baseDelta, symbol: review.symbol, decimals: sizeDecimals))"
                : nil
        ))

        rows.append(feeRow(estimatedFeeUsd: review.estimatedFeeUsd))

        if let autoCloseRow = autoCloseRow(
            from: autoClose,
            side: review.side,
            referencePrice: referencePrice,
            liquidationPrice: review.liquidationPrice
        ) {
            rows.append(autoCloseRow)
        }

        return rows
    }

    /// No Fee row: UpdateMargin carries no venue fee and the SDK review has no
    /// fee field — the design's Fee line has no honest number behind it.
    private static func makeMarginChangeRows(review: PerpsMarginChangeReview) -> [Row] {
        var rows: [Row] = []

        rows.append(payOrCloseRow(isAdd: review.direction == .add, usd: review.amountUsd))

        let liquidationValue: String
        if let liquidation = review.liquidationPrice {
            liquidationValue = liquidation.isChanged
                ? "\(PerpsFormatting.usd(liquidation.old)) → \(PerpsFormatting.usd(liquidation.new))"
                : PerpsFormatting.usd(liquidation.old)
        } else {
            liquidationValue = TKLocales.Perps.Confirm.unavailable
        }
        rows.append(Row(id: .liquidation, title: TKLocales.Perps.Confirm.liquidation, value: liquidationValue, subValue: nil))

        return rows
    }

    private static func liquidationRow(review: PerpsOpenOrderReview) -> Row {
        guard let liquidationPrice = review.liquidationPrice else {
            return Row(id: .liquidation, title: TKLocales.Perps.Confirm.liquidation, value: TKLocales.Perps.Confirm.unavailable, subValue: nil)
        }
        return Row(id: .liquidation, title: TKLocales.Perps.Confirm.liquidation, value: PerpsFormatting.usd(liquidationPrice), subValue: nil)
    }

    private static func autoCloseRow(
        from autoClose: PerpsAutoClose?,
        side: KeeperCore.PerpsTradeSide,
        referencePrice: Double,
        liquidationPrice: Double?
    ) -> Row? {
        guard let autoClose, !autoClose.isEmpty else { return nil }
        let invalid = PerpsAutoCloseValidation.invalidLegs(
            side: side,
            entryPrice: referencePrice,
            liquidationPrice: liquidationPrice,
            autoClose: autoClose
        )
        var parts: [ValuePart] = []
        if let takeProfit = autoClose.takeProfit {
            parts.append(ValuePart(
                text: "\(TKLocales.Perps.OpenPosition.tp) \(PerpsFormatting.compactUsd(takeProfit.triggerPrice))",
                tone: invalid.takeProfit ? .negative : .neutral
            ))
        }
        if let stopLoss = autoClose.stopLoss {
            if !parts.isEmpty {
                parts.append(ValuePart(text: " / ", tone: .tertiary))
            }
            parts.append(ValuePart(
                text: "\(TKLocales.Perps.OpenPosition.sl) \(PerpsFormatting.compactUsd(stopLoss.triggerPrice))",
                tone: invalid.stopLoss ? .negative : .neutral
            ))
        }
        let value = parts.map(\.text).joined()
        return Row(
            id: .autoClose,
            title: TKLocales.Perps.Confirm.autoClose,
            value: value,
            valueParts: parts,
            subValue: nil,
            showsChevron: true
        )
    }

    private static func usdtRow(id: Row.Kind, title: String, usd: Double) -> Row {
        Row(
            id: id,
            title: title,
            value: PerpsFormatting.usd(usd),
            subValue: "≈ \(PerpsFormatting.token(usd, symbol: "USDT", decimals: 2))"
        )
    }

    private static func payOrCloseRow(isAdd: Bool, usd: Double) -> Row {
        usdtRow(
            id: isAdd ? .youPay : .youClose,
            title: isAdd ? TKLocales.Perps.Confirm.youPay : TKLocales.Perps.Confirm.youClose,
            usd: usd
        )
    }

    private static func feeRow(estimatedFeeUsd: Double?) -> Row {
        Row(
            id: .fee,
            title: TKLocales.Perps.Confirm.fee,
            value: estimatedFeeUsd.map(PerpsFormatting.usd) ?? TKLocales.Perps.Confirm.unavailable,
            subValue: estimatedFeeUsd.map { "≈ \(PerpsFormatting.token($0, symbol: "USDT", decimals: 4))" }
        )
    }
}

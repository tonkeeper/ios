import Foundation
import PerpsModels
import SwiftUI
import TKLocalize

struct PerpsSetLimitPriceContext {
    enum PassedAutoClose {
        case blocks
        case isRemoved
    }

    let marketId: Int64
    let side: PerpsTradeSide
    let priceDecimals: Int
    let referencePrice: Double
    let initialLimitPrice: Double?
    var autoClose: PerpsAutoClose?
    var passedAutoClose: PassedAutoClose = .blocks
}

@MainActor
final class PerpsSetLimitPriceViewModel: ObservableObject, PerpsSetLimitPriceViewModeling {
    typealias QuickFill = PerpsSetLimitPriceQuickFill
    typealias QuickFillItem = PerpsSetLimitPriceQuickFillItem

    enum InputMode: Equatable {
        case price
        case percent
    }

    struct State: Equatable {
        var amountText: String = ""
        var inputMode: InputMode = .price
        var activeQuickFill: QuickFill?
        var referencePrice: Double
    }

    @Published private var state: State

    var onBack: (() -> Void)?
    var onClose: (() -> Void)?
    var onSet: ((Double) -> Void)?

    private let context: PerpsSetLimitPriceContext
    private let priceFeed: PerpsMarketPriceFeed

    private let format: PerpsFormatting

    init(context: PerpsSetLimitPriceContext, marketsStore: any PerpsMarketsStoring, format: PerpsFormatting) {
        self.format = format
        self.context = context
        priceFeed = PerpsMarketPriceFeed(marketId: context.marketId, store: marketsStore)
        var state = State(referencePrice: context.referencePrice)
        if let initial = context.initialLimitPrice, initial > 0 {
            state.amountText = PerpsDecimalInput.text(initial, decimals: context.priceDecimals)
        }
        self.state = state
        priceFeed.observe(self) { $0.applyReferencePrice() }
    }

    // MARK: - Lifecycle

    func onAppear() {
        priceFeed.subscribe()
        applyReferencePrice()
    }

    func onDisappear() {
        priceFeed.unsubscribe()
    }

    // MARK: - Derived display

    var referencePriceText: String {
        format.price(state.referencePrice)
    }

    var fieldPrefix: String {
        state.inputMode == .price ? "$" : ""
    }

    var fieldSuffix: String? {
        state.inputMode == .percent ? "%" : nil
    }

    var isAmountSigned: Bool {
        state.inputMode == .percent
    }

    var amountText: String {
        state.amountText
    }

    var chipText: String {
        switch state.inputMode {
        case .price:
            guard state.referencePrice > 0, let price = limitPrice(for: state) else { return Self.zeroPercent }
            let offset = (price - state.referencePrice) / state.referencePrice * 100
            if abs(offset) < 0.005 { return Self.zeroPercent }
            return format.signedPercent(offset)
        case .percent:
            return format.price(limitPrice(for: state) ?? state.referencePrice)
        }
    }

    var limitPrice: Double? {
        limitPrice(for: state)
    }

    var warningText: String? {
        priceWarningText(for: state) ?? autoCloseWarningText(for: state)
    }

    var isWarningBlocking: Bool {
        priceWarningText(for: state) != nil || context.passedAutoClose == .blocks
    }

    var isSetEnabled: Bool {
        guard limitPrice(for: state) != nil, priceWarningText(for: state) == nil else { return false }
        return context.passedAutoClose == .isRemoved || autoCloseWarningText(for: state) == nil
    }

    var quickFills: [QuickFillItem] {
        QuickFill.allCases.map { fill in
            QuickFillItem(fill: fill, title: title(for: fill), isActive: state.activeQuickFill == fill)
        }
    }

    // MARK: - Intent

    func setAmount(_ text: String) {
        update {
            $0.amountText = $0.inputMode == .percent ? sanitizeSignedPercent(text) : PerpsDecimalInput.sanitize(text, decimals: context.priceDecimals)
            $0.activeQuickFill = nil
        }
    }

    func toggleInputMode() {
        var draft = state
        let price = limitPrice(for: draft)
        draft.inputMode = draft.inputMode == .price ? .percent : .price
        draft.activeQuickFill = nil
        guard let price else {
            draft.amountText = ""
            update { $0 = draft }
            return
        }
        switch draft.inputMode {
        case .price:
            draft.amountText = PerpsDecimalInput.text(price, decimals: context.priceDecimals)
        case .percent:
            guard draft.referencePrice > 0 else {
                draft.amountText = ""
                update { $0 = draft }
                return
            }
            draft.amountText = Self.percentString((price - draft.referencePrice) / draft.referencePrice * 100, signed: true)
        }
        update { $0 = draft }
    }

    func applyQuickFill(_ fill: QuickFill) {
        var draft = state
        let price: Double
        switch fill {
        case .mid:
            price = draft.referencePrice
        case .p1, .p2, .p5:
            guard draft.referencePrice > 0 else { return }
            price = draft.referencePrice * (1 + signedPercent(for: fill) / 100)
        }
        guard price > 0 else { return }
        draft.activeQuickFill = fill
        switch draft.inputMode {
        case .price:
            draft.amountText = PerpsDecimalInput.text(price, decimals: context.priceDecimals)
        case .percent:
            let offset = draft.referencePrice > 0 ? (price - draft.referencePrice) / draft.referencePrice * 100 : signedPercent(for: fill)
            draft.amountText = Self.percentString(offset, signed: true)
        }
        update { $0 = draft }
    }

    func setLimit() {
        guard let price = limitPrice else { return }
        onSet?(price)
    }

    func back() {
        onBack?()
    }

    func close() {
        onClose?()
    }

    // MARK: - Private

    private func signedPercent(for fill: QuickFill) -> Double {
        switch fill {
        case .mid:
            return 0
        case .p1, .p2, .p5:
            return context.side == .long ? -fill.percent : fill.percent
        }
    }

    private func title(for fill: QuickFill) -> String {
        switch fill {
        case .mid:
            return TKLocales.Perps.SetLimitPrice.mid
        case .p1, .p2, .p5:
            let sign = context.side == .long ? "−" : "+"
            return "\(sign)\(Int(fill.percent))%"
        }
    }

    private func applyReferencePrice() {
        guard let price = priceFeed.price, price != state.referencePrice else { return }
        update { $0.referencePrice = price }
    }

    private func limitPrice(for state: State) -> Double? {
        switch state.inputMode {
        case .price:
            guard let price = PerpsDecimalInput.double(state.amountText), price > 0 else { return nil }
            return price
        case .percent:
            guard let percent = signedPercent(state.amountText), state.referencePrice > 0 else { return nil }
            let price = state.referencePrice * (1 + percent / 100)
            return price > 0 ? price : nil
        }
    }

    private func priceWarningText(for state: State) -> String? {
        guard let limitPrice = limitPrice(for: state), state.referencePrice > 0 else { return nil }
        switch context.side {
        case .long:
            return limitPrice <= state.referencePrice ? nil : TKLocales.Perps.SetLimitPrice.warningAtOrBelowCurrentPrice
        case .short:
            return limitPrice >= state.referencePrice ? nil : TKLocales.Perps.SetLimitPrice.warningAtOrAboveCurrentPrice
        }
    }

    private func autoCloseWarningText(for state: State) -> String? {
        guard let limitPrice = limitPrice(for: state), let autoClose = context.autoClose else { return nil }
        let passed = PerpsAutoCloseValidation.legsPassed(byLimitPrice: limitPrice, side: context.side, autoClose: autoClose)
        let isLong = context.side == .long
        let position: String
        let removal: String
        if passed.stopLoss, let price = autoClose.stopLoss?.triggerPrice {
            position = isLong
                ? TKLocales.Perps.SetLimitPrice.belowStopLoss(format.price(price))
                : TKLocales.Perps.SetLimitPrice.aboveStopLoss(format.price(price))
            removal = TKLocales.Perps.SetLimitPrice.stopLossRemoved
        } else if passed.takeProfit, let price = autoClose.takeProfit?.triggerPrice {
            position = isLong
                ? TKLocales.Perps.SetLimitPrice.aboveTakeProfit(format.price(price))
                : TKLocales.Perps.SetLimitPrice.belowTakeProfit(format.price(price))
            removal = TKLocales.Perps.SetLimitPrice.takeProfitRemoved
        } else {
            return nil
        }
        switch context.passedAutoClose {
        case .blocks: return position
        case .isRemoved: return "\(position). \(removal)"
        }
    }

    private func update(_ body: (inout State) -> Void) {
        var next = state
        body(&next)
        guard next != state else { return }
        state = next
    }

    private static let zeroPercent = "0%"

    private func signedPercent(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        let parseable = normalized.hasPrefix("+") ? String(normalized.dropFirst()) : normalized
        guard let decimal = Decimal(string: parseable, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return NSDecimalNumber(decimal: decimal).doubleValue
    }

    private func sanitizeSignedPercent(_ text: String) -> String {
        var sign = ""
        var unsigned = ""
        for character in text {
            if unsigned.isEmpty, sign.isEmpty, character == "+" || character == "-" || character == "−" {
                sign = character == "+" ? "+" : "-"
                continue
            }
            if character.isNumber || character == "." || character == "," {
                unsigned.append(character)
            }
        }
        return sign + PerpsDecimalInput.sanitize(unsigned, decimals: 2)
    }

    private static func percentString(_ value: Double, signed: Bool = false) -> String {
        let magnitude = PerpsDecimalInput.percentText(abs(value))
        guard signed, abs(value) >= 0.005 else { return magnitude }
        return (value > 0 ? "+" : "-") + magnitude
    }
}

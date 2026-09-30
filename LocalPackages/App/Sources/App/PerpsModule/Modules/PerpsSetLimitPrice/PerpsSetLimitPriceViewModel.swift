import Foundation
import KeeperCore
import SwiftUI
import TKLocalize

struct PerpsSetLimitPriceContext {
    let marketId: Int64
    let side: PerpsTradeSide
    let priceDecimals: Int
    let referencePrice: Double
    let initialLimitPrice: Double?
}

@MainActor
final class PerpsSetLimitPriceViewModel: ObservableObject {
    enum InputMode: Equatable {
        case price
        case percent
    }

    enum QuickFill: Hashable, CaseIterable {
        case mid, p1, p2, p5

        var percent: Double {
            switch self {
            case .mid: return 0
            case .p1: return 1
            case .p2: return 2
            case .p5: return 5
            }
        }
    }

    struct QuickFillItem: Identifiable {
        let fill: QuickFill
        let title: String
        let isActive: Bool
        var id: QuickFill {
            fill
        }
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
    private let marketsStore: PerpsMarketsStore
    private let priceInterest: PerpsMarketsPriceInterest

    init(context: PerpsSetLimitPriceContext, marketsStore: PerpsMarketsStore) {
        self.context = context
        self.marketsStore = marketsStore
        priceInterest = marketsStore.makePriceInterest()
        var state = State(referencePrice: context.referencePrice)
        if let initial = context.initialLimitPrice, initial > 0 {
            state.amountText = PerpsDecimalInput.text(initial, decimals: context.priceDecimals)
        }
        self.state = state
        observeStore()
    }

    // MARK: - Lifecycle

    func onAppear() {
        priceInterest.set(marketIds: [context.marketId])
        applyMarketsStoreState()
    }

    func onDisappear() {
        priceInterest.clear()
    }

    // MARK: - Derived display

    var referencePriceText: String {
        PerpsFormatting.usd(state.referencePrice)
    }

    var fieldPrefix: String {
        state.inputMode == .price ? "$" : ""
    }

    var fieldSuffix: String? {
        state.inputMode == .percent ? "%" : nil
    }

    var amountText: String {
        state.amountText
    }

    var activeQuickFill: QuickFill? {
        state.activeQuickFill
    }

    var chipText: String {
        switch state.inputMode {
        case .price:
            guard state.referencePrice > 0, let price = limitPrice(for: state) else { return Self.zeroPercent }
            let offset = (price - state.referencePrice) / state.referencePrice * 100
            if abs(offset) < 0.005 { return Self.zeroPercent }
            return PerpsFormatting.signedPercent(offset)
        case .percent:
            return PerpsFormatting.usd(limitPrice(for: state) ?? state.referencePrice)
        }
    }

    var limitPrice: Double? {
        limitPrice(for: state)
    }

    var warningText: String? {
        warningText(for: state)
    }

    var isSetEnabled: Bool {
        limitPrice(for: state) != nil && warningText(for: state) == nil
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
            return "\(sign)\(Int(fill.percent))\u{2009}%"
        }
    }

    private func observeStore() {
        marketsStore.addObserver(self) { observer, _ in
            Task { @MainActor in observer.applyMarketsStoreState() }
        }
    }

    private func applyMarketsStoreState() {
        let state = marketsStore.getState()
        applyReferencePrice(state.price(marketId: context.marketId))
    }

    private func applyReferencePrice(_ price: Double?) {
        guard let price, price > 0, price != state.referencePrice else { return }
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

    private func warningText(for state: State) -> String? {
        guard let limitPrice = limitPrice(for: state), state.referencePrice > 0 else { return nil }
        switch context.side {
        case .long:
            return limitPrice <= state.referencePrice ? nil : TKLocales.Perps.SetLimitPrice.warningAtOrBelowCurrentPrice
        case .short:
            return limitPrice >= state.referencePrice ? nil : TKLocales.Perps.SetLimitPrice.warningAtOrAboveCurrentPrice
        }
    }

    private func update(_ body: (inout State) -> Void) {
        var next = state
        body(&next)
        guard next != state else { return }
        state = next
    }

    private static let zeroPercent = "0\u{2009}%"

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

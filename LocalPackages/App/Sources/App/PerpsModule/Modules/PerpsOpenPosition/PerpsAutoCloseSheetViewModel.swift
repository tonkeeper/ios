import Foundation
import KeeperCore
import SwiftUI

@MainActor
final class PerpsAutoCloseSheetViewModel: ObservableObject {
    enum Leg {
        case takeProfit
        case stopLoss
    }

    @Published var takeProfitPercentText: String = ""
    @Published var takeProfitPriceText: String = ""
    @Published var stopLossPercentText: String = ""
    @Published var stopLossPriceText: String = ""
    @Published private(set) var isSubmitting = false
    @Published private(set) var submitErrorText: String?

    let side: KeeperCore.PerpsTradeSide
    let entryPrice: Double
    let leverage: Double
    let liquidationPrice: Double?

    let takeProfitPresets: [Double] = [10, 20, 50, 100]
    let stopLossPresets: [Double] = [5, 10, 25, 50]

    var onApply: ((PerpsAutoClose?) -> Void)?
    var onClose: (() -> Void)?
    /// Live-position mode: Set submits to the venue and awaits it (designed
    /// loading state on the button); the handler returns an inline error text,
    /// or nil when the coordinator closed the sheet. The open flow leaves this
    /// nil and applies drafts instantly via `onApply`.
    var onSubmit: ((PerpsAutoClose?) async -> String?)?

    init(context: PerpsAutoCloseSheetContext) {
        side = context.side
        entryPrice = context.entryPrice
        leverage = context.leverage
        liquidationPrice = context.liquidationPrice
        hadDraft = context.draft != nil
        // Prefill keeps the full trigger precision: on fine-tick markets a
        // 2-decimal render would make an untouched Set move the resting legs.
        if let tp = context.draft?.takeProfit?.triggerPrice {
            takeProfitPriceText = exactText(tp)
            takeProfitPercentText = percentText(fromPrice: tp)
        }
        if let sl = context.draft?.stopLoss?.triggerPrice {
            stopLossPriceText = exactText(sl)
            stopLossPercentText = percentText(fromPrice: sl)
        }
    }

    var takeProfitPrice: Double? {
        parse(takeProfitPriceText)
    }

    var stopLossPrice: Double? {
        parse(stopLossPriceText)
    }

    var takeProfitWarningText: String? {
        PerpsAutoCloseValidation.warning(
            side: side,
            entryPrice: entryPrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: takeProfitPrice,
            stopLossPrice: nil
        )?.message
    }

    var stopLossWarningText: String? {
        PerpsAutoCloseValidation.warning(
            side: side,
            entryPrice: entryPrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: nil,
            stopLossPrice: stopLossPrice
        )?.message
    }

    var isValid: Bool {
        takeProfitWarningText == nil && stopLossWarningText == nil
    }

    /// Live mode disables Set when there is nothing to set and nothing to clear
    /// (design's Empty state); an empty sheet over resting legs stays enabled —
    /// that Set is the clear action. The open flow keeps empty-Set as "no draft".
    var isApplyEnabled: Bool {
        guard isValid else { return false }
        guard onSubmit != nil else { return true }
        return takeProfitPrice != nil || stopLossPrice != nil || hadDraft
    }

    private let hadDraft: Bool

    // MARK: - Input (each field keeps its sibling in sync)

    func setTakeProfitPercent(_ text: String) {
        takeProfitPercentText = sanitize(text)
        takeProfitPriceText = priceText(fromPercentText: takeProfitPercentText, leg: .takeProfit)
    }

    func setTakeProfitPrice(_ text: String) {
        takeProfitPriceText = sanitize(text)
        takeProfitPercentText = percentText(fromPriceText: takeProfitPriceText)
    }

    func setStopLossPercent(_ text: String) {
        stopLossPercentText = sanitize(text)
        stopLossPriceText = priceText(fromPercentText: stopLossPercentText, leg: .stopLoss)
    }

    func setStopLossPrice(_ text: String) {
        stopLossPriceText = sanitize(text)
        stopLossPercentText = percentText(fromPriceText: stopLossPriceText)
    }

    func applyTakeProfitPreset(_ percent: Double) {
        setTakeProfitPercent(trimmed(percent))
    }

    func applyStopLossPreset(_ percent: Double) {
        setStopLossPercent(trimmed(percent))
    }

    func apply() {
        guard isApplyEnabled, !isSubmitting else { return }
        let tp = takeProfitPrice.map { PerpsAutoCloseTrigger(triggerPrice: $0) }
        let sl = stopLossPrice.map { PerpsAutoCloseTrigger(triggerPrice: $0) }
        let autoClose = (tp == nil && sl == nil) ? nil : PerpsAutoClose(takeProfit: tp, stopLoss: sl)
        guard let onSubmit else {
            onApply?(autoClose)
            return
        }
        submitErrorText = nil
        isSubmitting = true
        Task { @MainActor [weak self] in
            let error = await onSubmit(autoClose)
            guard let self else { return }
            isSubmitting = false
            submitErrorText = (error?.isEmpty == false) ? error : nil
        }
    }

    // MARK: - ROI ↔ price

    private func price(fromROI roi: Double, leg: Leg) -> Double? {
        guard entryPrice > 0, leverage > 0 else { return nil }
        let fraction = roi / 100 / leverage
        switch (side, leg) {
        case (.long, .takeProfit), (.short, .stopLoss):
            return entryPrice * (1 + fraction)
        case (.long, .stopLoss), (.short, .takeProfit):
            return entryPrice * (1 - fraction)
        }
    }

    private func roi(fromPrice price: Double) -> Double? {
        guard entryPrice > 0, leverage > 0 else { return nil }
        return abs(price / entryPrice - 1) * leverage * 100
    }

    private func priceText(fromPercentText text: String, leg: Leg) -> String {
        guard let roi = parse(text), let price = price(fromROI: roi, leg: leg) else { return "" }
        return trimmed(price)
    }

    private func percentText(fromPriceText text: String) -> String {
        guard let price = parse(text) else { return "" }
        return percentText(fromPrice: price)
    }

    private func percentText(fromPrice price: Double) -> String {
        guard let roi = roi(fromPrice: price) else { return "" }
        return trimmed(roi)
    }

    private func parse(_ text: String) -> Double? {
        guard let value = PerpsDecimalInput.double(text), value > 0 else { return nil }
        return value
    }

    private func sanitize(_ text: String) -> String {
        AmountInputFormatter.normalizedString(
            text,
            decimalSeparator: ".",
            maximumFractionDigits: 2,
            interpretsLeadingZeroAsFractionalShortcut: false
        ) ?? ""
    }

    private func trimmed(_ value: Double) -> String {
        PerpsDecimalInput.inputText(from: value)
    }

    private func exactText(_ value: Double) -> String {
        // Swift's Double description is the shortest round-tripping form —
        // exact without binary-noise tails; expand the rare scientific form.
        let text = "\(value)"
        guard text.lowercased().contains("e") else { return text }
        var expanded = String(format: "%.12f", value)
        while expanded.hasSuffix("0") {
            expanded.removeLast()
        }
        if expanded.hasSuffix(".") { expanded.removeLast() }
        return expanded
    }
}

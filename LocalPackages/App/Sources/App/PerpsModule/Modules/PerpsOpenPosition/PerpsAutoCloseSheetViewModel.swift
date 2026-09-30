import Foundation
import KeeperCore
import SwiftUI

@MainActor
final class PerpsAutoCloseSheetViewModel: ObservableObject {
    enum Leg {
        case takeProfit
        case stopLoss
    }

    /// What Set means on this sheet. The open and size-change flows edit a
    /// draft the owner keeps; a live position submits to the venue, which is
    /// the only case with a loading state and an inline failure.
    enum Apply {
        case draft((PerpsAutoClose?) -> Void)
        case submit((PerpsAutoClose?) async -> ApplyResult)
    }

    /// `finished` means the form has nothing left to show: the owner closed the
    /// sheet, or the user backed out of the confirmation.
    enum ApplyResult {
        case finished
        case failed(String)

        var failureText: String? {
            switch self {
            case .finished: nil
            case let .failed(message): message
            }
        }
    }

    @Published var takeProfitPercentText: String = ""
    @Published var takeProfitPriceText: String = ""
    @Published var stopLossPercentText: String = ""
    @Published var stopLossPriceText: String = ""
    @Published private(set) var isSubmitting = false
    @Published private(set) var submitErrorText: String?

    let side: PerpsTradeSide
    let entryPrice: Double
    let referencePrice: Double
    let leverage: Double
    let liquidationPrice: Double?
    let priceDecimals: Int

    let takeProfitPresets: [Double] = [10, 20, 50, 100]
    let stopLossPresets: [Double] = [5, 10, 25, 50]

    var onApply: Apply?
    var onClose: (() -> Void)?

    init(context: PerpsAutoCloseSheetContext) {
        side = context.side
        entryPrice = context.entryPrice
        referencePrice = context.referencePrice
        leverage = context.leverage
        liquidationPrice = context.liquidationPrice
        priceDecimals = context.priceDecimals
        hadDraft = context.draft != nil
        if let tp = context.draft?.takeProfit?.triggerPrice {
            takeProfitPriceText = priceText(tp)
            takeProfitPercentText = percentText(fromPrice: tp)
        }
        if let sl = context.draft?.stopLoss?.triggerPrice {
            stopLossPriceText = priceText(sl)
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
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: takeProfitPrice,
            stopLossPrice: nil
        )?.message
    }

    var stopLossWarningText: String? {
        PerpsAutoCloseValidation.warning(
            side: side,
            referencePrice: referencePrice,
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
        guard case .some(.submit) = onApply else { return true }
        return takeProfitPrice != nil || stopLossPrice != nil || hadDraft
    }

    private let hadDraft: Bool

    // MARK: - Input (each field keeps its sibling in sync)

    func setTakeProfitPercent(_ text: String) {
        takeProfitPercentText = sanitizePercent(text)
        takeProfitPriceText = priceText(fromPercentText: takeProfitPercentText, leg: .takeProfit)
    }

    func setTakeProfitPrice(_ text: String) {
        takeProfitPriceText = sanitizePrice(text)
        takeProfitPercentText = percentText(fromPriceText: takeProfitPriceText)
    }

    func setStopLossPercent(_ text: String) {
        stopLossPercentText = sanitizePercent(text)
        stopLossPriceText = priceText(fromPercentText: stopLossPercentText, leg: .stopLoss)
    }

    func setStopLossPrice(_ text: String) {
        stopLossPriceText = sanitizePrice(text)
        stopLossPercentText = percentText(fromPriceText: stopLossPriceText)
    }

    func applyTakeProfitPreset(_ percent: Double) {
        setTakeProfitPercent(percentText(percent))
    }

    func applyStopLossPreset(_ percent: Double) {
        setStopLossPercent(percentText(percent))
    }

    func apply() {
        guard isApplyEnabled, !isSubmitting else { return }
        let tp = takeProfitPrice.map { PerpsAutoCloseTrigger(triggerPrice: $0) }
        let sl = stopLossPrice.map { PerpsAutoCloseTrigger(triggerPrice: $0) }
        let autoClose = (tp == nil && sl == nil) ? nil : PerpsAutoClose(takeProfit: tp, stopLoss: sl)
        guard let onApply else { return }
        switch onApply {
        case let .draft(apply):
            apply(autoClose)
        case let .submit(submit):
            submitErrorText = nil
            isSubmitting = true
            Task { @MainActor [weak self] in
                let result = await submit(autoClose)
                guard let self else { return }
                isSubmitting = false
                submitErrorText = result.failureText
            }
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
        return priceText(price)
    }

    private func percentText(fromPriceText text: String) -> String {
        guard let price = parse(text) else { return "" }
        return percentText(fromPrice: price)
    }

    private func percentText(fromPrice price: Double) -> String {
        guard let roi = roi(fromPrice: price) else { return "" }
        return percentText(roi)
    }

    private func parse(_ text: String) -> Double? {
        guard let value = PerpsDecimalInput.double(text), value > 0 else { return nil }
        return value
    }

    // MARK: - Precision (a trigger is a market price, a percent is ROI on margin)

    private func sanitizePrice(_ text: String) -> String {
        PerpsDecimalInput.sanitize(text, decimals: priceDecimals)
    }

    private func sanitizePercent(_ text: String) -> String {
        PerpsDecimalInput.sanitize(text, decimals: 2)
    }

    private func priceText(_ value: Double) -> String {
        PerpsDecimalInput.text(value, decimals: priceDecimals)
    }

    private func percentText(_ value: Double) -> String {
        PerpsDecimalInput.percentText(value)
    }
}

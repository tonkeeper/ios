import Foundation
import PerpsModels
import SwiftUI
import TKLocalize

@MainActor
final class PerpsAutoCloseSheetViewModel: ObservableObject, PerpsAutoCloseSheetViewModeling {
    /// What Set means on this sheet. The open and size-change flows edit a
    /// draft the owner keeps; a live position submits to the venue, which is
    /// the only case with a loading state and an inline failure.
    enum Apply {
        case draft((PerpsAutoClose?, PerpsAutoCloseROIInput) -> Void)
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
    @Published private(set) var takeProfitPercentSign: FloatingPointSign = .plus
    @Published private(set) var stopLossPercentSign: FloatingPointSign = .minus
    @Published private(set) var isSubmitting = false
    @Published private(set) var submitErrorText: String?
    @Published private(set) var referencePrice: Double

    var side: PerpsTradeSide {
        base.side
    }

    var entryPrice: Double {
        base.entryPrice
    }

    var leverage: Double {
        base.leverage
    }

    let baseSize: Double
    let liquidationPrice: Double?
    var priceDecimals: Int {
        base.priceDecimals
    }

    let takeProfitPresets: [Double] = [10, 20, 50, 100]
    let stopLossPresets: [Double] = [5, 10, 25, 50]

    var onApply: Apply?
    var onClose: (() -> Void)?

    private let format: PerpsFormatting
    private let priceFeed: PerpsMarketPriceFeed?
    private let base: PerpsAutoCloseBase
    private let inputMemory: PerpsAutoCloseInputMemory.Slot?
    private var takeProfitTypedAsROI = false
    private var stopLossTypedAsROI = false
    private var didEditTakeProfit = false
    private var didEditStopLoss = false

    init(
        context: PerpsAutoCloseSheetContext,
        format: PerpsFormatting,
        marketsStore: (any PerpsMarketsStoring)? = nil,
        inputMemory: PerpsAutoCloseInputMemory.Slot? = nil
    ) {
        self.format = format
        self.inputMemory = inputMemory
        priceFeed = marketsStore.flatMap { store in
            context.livePriceMarketId.map { PerpsMarketPriceFeed(marketId: $0, store: store) }
        }
        referencePrice = context.referencePrice
        baseSize = context.baseSize
        liquidationPrice = context.liquidationPrice
        base = PerpsAutoCloseBase(
            side: context.side,
            entryPrice: context.entryPrice,
            leverage: context.leverage,
            priceDecimals: context.priceDecimals
        )
        hadDraft = context.draft != nil
        let remembered = inputMemory?.input ?? .none
        if let tp = context.draft?.takeProfit?.triggerPrice {
            takeProfitPriceText = priceText(tp)
            (takeProfitPercentSign, takeProfitPercentText, takeProfitTypedAsROI) = percentField(
                for: tp,
                typed: context.roiInput.takeProfit,
                remembered: remembered.takeProfit,
                defaultSign: .plus
            )
            if takeProfitTypedAsROI {
                takeProfitPriceText = priceText(fromPercentText: takeProfitPercentText, sign: takeProfitPercentSign)
            }
        }
        if let sl = context.draft?.stopLoss?.triggerPrice {
            stopLossPriceText = priceText(sl)
            (stopLossPercentSign, stopLossPercentText, stopLossTypedAsROI) = percentField(
                for: sl,
                typed: context.roiInput.stopLoss,
                remembered: remembered.stopLoss,
                defaultSign: .minus
            )
            if stopLossTypedAsROI {
                stopLossPriceText = priceText(fromPercentText: stopLossPercentText, sign: stopLossPercentSign)
            }
        }
        priceFeed?.subscribe()
        priceFeed?.observe(self) { $0.applyLivePrice() }
    }

    private func applyLivePrice() {
        guard let price = priceFeed?.livePrice, price != referencePrice else { return }
        referencePrice = price
    }

    var takeProfitPrice: Double? {
        parse(takeProfitPriceText)
    }

    var stopLossPrice: Double? {
        parse(stopLossPriceText)
    }

    var takeProfitWarningText: String? {
        if takeProfitTypedAsROI, !takeProfitPercentText.isEmpty, takeProfitPrice == nil {
            return TKLocales.Perps.Error.autoCloseInvalid
        }
        return PerpsAutoCloseValidation.warning(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: takeProfitPrice,
            stopLossPrice: nil,
            format: format
        )?.message
    }

    var stopLossWarningText: String? {
        if stopLossTypedAsROI, !stopLossPercentText.isEmpty, stopLossPrice == nil {
            return TKLocales.Perps.Error.autoCloseInvalid
        }
        return PerpsAutoCloseValidation.warning(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: liquidationPrice,
            takeProfitPrice: nil,
            stopLossPrice: stopLossPrice,
            format: format
        )?.message
    }

    var isValid: Bool {
        takeProfitWarningText == nil && stopLossWarningText == nil
    }

    var takeProfitExpectedText: String {
        guard let value = expectedUsd(takeProfitPrice) else {
            return TKLocales.Perps.OpenPosition.takeProfitHint
        }
        return expectedText(value)
    }

    var stopLossExpectedText: String {
        guard let value = expectedUsd(stopLossPrice) else {
            return TKLocales.Perps.OpenPosition.stopLossHint
        }
        return expectedText(value)
    }

    private func expectedText(_ value: Double) -> String {
        let formatted = format.signedUsd(value)
        return value >= 0
            ? TKLocales.Perps.OpenPosition.expectedProfit(formatted)
            : TKLocales.Perps.OpenPosition.expectedLoss(formatted)
    }

    private var triggersPointTheRightWay: Bool {
        guard !roiInput.hasInvalidPrice(on: base) else { return false }
        return PerpsAutoCloseValidation.warning(
            side: side,
            referencePrice: referencePrice,
            liquidationPrice: nil,
            takeProfitPrice: takeProfitPrice,
            stopLossPrice: stopLossPrice,
            format: format
        ) == nil
    }

    /// Live mode disables Set when there is nothing to set and nothing to clear
    /// (design's Empty state); an empty sheet over resting legs stays enabled —
    /// that Set is the clear action. The open flow keeps empty-Set as "no draft".
    var isApplyEnabled: Bool {
        guard triggersPointTheRightWay else { return false }
        guard case .some(.submit) = onApply else { return true }
        return takeProfitPrice != nil || stopLossPrice != nil || hadDraft
    }

    private let hadDraft: Bool

    // MARK: - Input (each field keeps its sibling in sync)

    func setTakeProfitPercent(_ text: String) {
        didEditTakeProfit = true
        takeProfitPercentText = sanitizePercent(text)
        if takeProfitPercentText.isEmpty { takeProfitPercentSign = .plus }
        takeProfitPriceText = priceText(fromPercentText: takeProfitPercentText, sign: takeProfitPercentSign)
        takeProfitTypedAsROI = true
    }

    func setTakeProfitPrice(_ text: String) {
        didEditTakeProfit = true
        takeProfitPriceText = sanitizePrice(text)
        (takeProfitPercentSign, takeProfitPercentText) = percent(fromPriceText: takeProfitPriceText, defaultSign: .plus)
        takeProfitTypedAsROI = false
    }

    func setStopLossPercent(_ text: String) {
        didEditStopLoss = true
        stopLossPercentText = sanitizePercent(text)
        if stopLossPercentText.isEmpty { stopLossPercentSign = .minus }
        stopLossPriceText = priceText(fromPercentText: stopLossPercentText, sign: stopLossPercentSign)
        stopLossTypedAsROI = true
    }

    func setStopLossPrice(_ text: String) {
        didEditStopLoss = true
        stopLossPriceText = sanitizePrice(text)
        (stopLossPercentSign, stopLossPercentText) = percent(fromPriceText: stopLossPriceText, defaultSign: .minus)
        stopLossTypedAsROI = false
    }

    func applyTakeProfitPreset(_ percent: Double) {
        takeProfitPercentSign = .plus
        setTakeProfitPercent(percentText(percent))
    }

    func applyStopLossPreset(_ percent: Double) {
        stopLossPercentSign = .minus
        setStopLossPercent(percentText(percent))
    }

    func apply() {
        guard isApplyEnabled, !isSubmitting else { return }
        let tp = takeProfitPrice.map { PerpsAutoCloseTrigger(triggerPrice: $0) }
        let sl = stopLossPrice.map { PerpsAutoCloseTrigger(triggerPrice: $0) }
        let autoClose = (tp == nil && sl == nil) ? nil : PerpsAutoClose(takeProfit: tp, stopLoss: sl)
        guard let onApply else { return }
        let roiInput = roiInput
        if let inputMemory {
            inputMemory.remember(PerpsAutoCloseROIInput(
                takeProfit: roiInput.takeProfit ?? (didEditTakeProfit ? nil : inputMemory.input.takeProfit),
                stopLoss: roiInput.stopLoss ?? (didEditStopLoss ? nil : inputMemory.input.stopLoss)
            ))
        }
        switch onApply {
        case let .draft(apply):
            apply(autoClose, roiInput)
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

    var roiInput: PerpsAutoCloseROIInput {
        PerpsAutoCloseROIInput(
            takeProfit: typedROI(takeProfitTypedAsROI, takeProfitPercentSign, takeProfitPercentText),
            stopLoss: typedROI(stopLossTypedAsROI, stopLossPercentSign, stopLossPercentText)
        )
    }

    private func typedROI(
        _ isTyped: Bool,
        _ sign: FloatingPointSign,
        _ text: String
    ) -> PerpsAutoCloseROI? {
        guard isTyped, !text.isEmpty else { return nil }
        return PerpsAutoCloseROI(sign: sign, text: text)
    }

    /// The ROI the user typed for this leg while it still names the leg's price,
    /// otherwise the percent the price reads as on this sheet's base.
    private func percentField(
        for price: Double,
        typed input: PerpsAutoCloseROI?,
        remembered: PerpsAutoCloseROI?,
        defaultSign: FloatingPointSign
    ) -> (FloatingPointSign, String, Bool) {
        if let input, input.value.flatMap(base.triggerPrice(roi:)) == nil {
            return (input.sign, input.text, true)
        }
        if let typed = [input, remembered].compactMap({ $0 }).first(where: { base.names(price, by: $0) }) {
            return (typed.sign, typed.text, true)
        }
        let (sign, text) = percent(fromPrice: price, defaultSign: defaultSign)
        return (sign, text, false)
    }

    private func priceText(fromPercentText text: String, sign: FloatingPointSign) -> String {
        guard let magnitude = PerpsDecimalInput.double(text),
              let price = base.triggerPrice(roi: sign == .minus ? -magnitude : magnitude)
        else { return "" }
        return priceText(price)
    }

    private func percent(fromPriceText text: String, defaultSign: FloatingPointSign) -> (FloatingPointSign, String) {
        guard let price = parse(text) else { return (defaultSign, "") }
        return percent(fromPrice: price, defaultSign: defaultSign)
    }

    private func percent(fromPrice price: Double, defaultSign: FloatingPointSign) -> (FloatingPointSign, String) {
        guard let roi = base.roi(triggerPrice: price) else { return (defaultSign, "") }
        return (roi == 0 ? defaultSign : roi.sign, percentText(roi.magnitude))
    }

    func displayText(_ rawText: String) -> String {
        format.plain(rawText)
    }

    private func parse(_ text: String) -> Double? {
        guard let value = PerpsDecimalInput.double(text), value > 0 else { return nil }
        return value
    }

    private func expectedUsd(_ triggerPrice: Double?) -> Double? {
        guard baseSize > 0, entryPrice > 0, let triggerPrice, triggerPrice > 0 else { return nil }
        return PerpsTriggerROI.pnlUsd(
            side: side, entryPrice: entryPrice, baseAmount: baseSize, triggerPrice: triggerPrice
        )
    }

    // MARK: - Precision (a trigger is a market price, a percent is ROI on margin)

    private func sanitizePrice(_ text: String) -> String {
        PerpsDecimalInput.sanitize(text, decimals: priceDecimals)
    }

    private func sanitizePercent(_ text: String) -> String {
        PerpsDecimalInput.sanitize(text, decimals: 2)
    }

    private func priceText(_ value: Double) -> String {
        base.priceText(value)
    }

    private func percentText(_ value: Double) -> String {
        PerpsDecimalInput.percentText(value)
    }
}

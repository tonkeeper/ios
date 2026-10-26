import Foundation
import PerpsModels

/// A leg's ROI exactly as the user typed it.
public struct PerpsAutoCloseROI: Equatable, Sendable {
    public let sign: FloatingPointSign
    public let text: String

    public init(sign: FloatingPointSign, text: String) {
        self.sign = sign
        self.text = text
    }

    var value: Double? {
        PerpsDecimalInput.double(text).map { sign == .minus ? -$0 : $0 }
    }
}

/// The ROI typed for each leg. A leg typed as a price has none: the trigger price
/// is its input. Kept apart from `PerpsAutoClose` on purpose — that one is what the
/// venue holds and is diffed against the resting legs by equality.
public struct PerpsAutoCloseROIInput: Equatable, Sendable {
    public var takeProfit: PerpsAutoCloseROI?
    public var stopLoss: PerpsAutoCloseROI?

    public static let none = PerpsAutoCloseROIInput()

    public init(takeProfit: PerpsAutoCloseROI? = nil, stopLoss: PerpsAutoCloseROI? = nil) {
        self.takeProfit = takeProfit
        self.stopLoss = stopLoss
    }

    func keeping(legsOf autoClose: PerpsAutoClose?) -> PerpsAutoCloseROIInput {
        PerpsAutoCloseROIInput(
            takeProfit: autoClose?.takeProfit == nil ? nil : takeProfit,
            stopLoss: autoClose?.stopLoss == nil ? nil : stopLoss
        )
    }

    /// The draft with every typed-ROI leg re-derived on `base`; a leg typed as a
    /// price keeps it. An unplaceable ROI keeps its leg until the input is fixed.
    func resolving(_ autoClose: PerpsAutoClose?, on base: PerpsAutoCloseBase) -> PerpsAutoClose? {
        guard let autoClose else { return nil }
        func resolved(_ leg: PerpsAutoCloseTrigger?, _ roi: PerpsAutoCloseROI?) -> PerpsAutoCloseTrigger? {
            guard leg != nil, let roi else { return leg }
            guard let price = roi.value.flatMap(base.triggerPrice(roi:)) else { return leg }
            return PerpsAutoCloseTrigger(triggerPrice: price)
        }
        let resolved = PerpsAutoClose(
            takeProfit: resolved(autoClose.takeProfit, takeProfit),
            stopLoss: resolved(autoClose.stopLoss, stopLoss)
        )
        return resolved.isEmpty ? nil : resolved
    }

    func hasInvalidPrice(on base: PerpsAutoCloseBase) -> Bool {
        [takeProfit, stopLoss].compactMap { $0 }.contains {
            $0.value.flatMap(base.triggerPrice(roi:)) == nil
        }
    }
}

/// What a typed ROI is measured against, and the market tick its price lands on.
struct PerpsAutoCloseBase: Equatable {
    let side: PerpsTradeSide
    let entryPrice: Double
    let leverage: Double
    let priceDecimals: Int

    func triggerPrice(roi: Double) -> Double? {
        PerpsTriggerROI.triggerPrice(side: side, entryPrice: entryPrice, leverage: leverage, percent: roi)
            .flatMap { PerpsDecimalInput.double(priceText($0)) }
            .flatMap { $0 > 0 ? $0 : nil }
    }

    func roi(triggerPrice: Double) -> Double? {
        PerpsTriggerROI.percent(side: side, entryPrice: entryPrice, leverage: leverage, triggerPrice: triggerPrice)
    }

    func priceText(_ price: Double) -> String {
        PerpsDecimalInput.text(price, decimals: priceDecimals)
    }

    /// Whether `roi` still names exactly this trigger price here. Only then may the
    /// typed ROI stand in for it: a changed entry, leverage or leg breaks it.
    func names(_ triggerPrice: Double, by roi: PerpsAutoCloseROI) -> Bool {
        guard let value = roi.value, let price = self.triggerPrice(roi: value) else { return false }
        return priceText(price) == priceText(triggerPrice)
    }
}

/// The ROI the user typed per venue account and market, for this app launch only.
/// A sheet shows a remembered ROI only while it still names the leg's trigger
/// price, so a stale entry can never be shown — at worst it goes unused.
@MainActor
final class PerpsAutoCloseInputMemory {
    static let shared = PerpsAutoCloseInputMemory()

    @MainActor
    struct Slot {
        fileprivate let memory: PerpsAutoCloseInputMemory
        fileprivate let key: Key

        var input: PerpsAutoCloseROIInput {
            memory.inputs[key] ?? .none
        }

        func remember(_ input: PerpsAutoCloseROIInput) {
            memory.inputs[key] = input == .none ? nil : input
        }
    }

    fileprivate struct Key: Hashable {
        let accountIndex: Int64
        let marketId: Int64
    }

    private var inputs = [Key: PerpsAutoCloseROIInput]()

    func slot(accountIndex: Int64, marketId: Int64) -> Slot {
        Slot(memory: self, key: Key(accountIndex: accountIndex, marketId: marketId))
    }
}

import BigInt
import Foundation
import KeeperCore
import TKLocalize

/// Min/max checks for the deposit amount, mirroring `InsertAmountViewModel`
/// (`+Validation`, `+Configuration`): limits come from the merchant quote, falling back to the
/// provider limits of the payment method; `min` rounds down and `max` rounds up in smallest units.
struct RampLimitsEvaluator {
    enum Violation: Equatable {
        case belowMin(message: String)
        case aboveMax(message: String)

        var message: String {
            switch self {
            case let .belowMin(message), let .aboveMax(message):
                message
            }
        }
    }

    let fractionalDigits: Int
    let currencyCode: String
    let providers: [OnRampProvider]
    let merchantIds: [String]
    let quotes: InsertAmountQuotesState?

    func limits(for merchantId: String) -> OnRampLimits? {
        let layout = providers.first { $0.merchantId == merchantId }?.limits
        let quote = quote(for: merchantId)
        let min = (quote?.minAmount ?? layout?.min).flatMap { $0 > 0 ? $0 : nil }
        let max = (quote?.maxAmount ?? layout?.max).flatMap { $0 > 0 ? $0 : nil }
        guard min != nil || max != nil else { return nil }
        return OnRampLimits(min: min, max: max)
    }

    func quote(for merchantId: String) -> InsertAmountMerchantQuote? {
        quotes?.quotes.first { $0.merchantId == merchantId }
            ?? quotes?.suggestedQuotes.first { $0.merchantId == merchantId }
    }

    func canServe(merchantId: String, amount: BigUInt) -> Bool {
        let limits = limits(for: merchantId)
        if let min = limits?.min, amount < smallestUnits(min, roundingMode: .down) {
            return false
        }
        if let max = limits?.max, amount > smallestUnits(max, roundingMode: .up) {
            return false
        }
        return true
    }

    func hasServiceableMerchant(amount: BigUInt) -> Bool {
        merchantIds.contains { canServe(merchantId: $0, amount: amount) }
    }

    /// Server order: quotes, then suggested quotes; without quotes, the provider order.
    var orderedMerchantIds: [String] {
        guard let quotes else {
            return providers.map(\.merchantId).filter(merchantIds.contains)
        }
        var seen = Set<String>()
        let serverOrder = quotes.quotes.map(\.merchantId) + quotes.suggestedQuotes.map(\.merchantId)
        return serverOrder.filter { merchantIds.contains($0) && seen.insert($0).inserted }
    }

    func bestMerchantId(amount: BigUInt) -> String? {
        let ordered = orderedMerchantIds
        if let serviceable = ordered.first(where: { canServe(merchantId: $0, amount: amount) }) {
            return serviceable
        }
        return closestBelowMinMerchantId(amount: amount) ?? ordered.first
    }

    /// When no merchant serves the amount: the one whose `min` is the nearest above it.
    func closestBelowMinMerchantId(amount: BigUInt) -> String? {
        orderedMerchantIds
            .compactMap { id -> (id: String, min: Double)? in
                guard let min = limits(for: id)?.min,
                      amount < smallestUnits(min, roundingMode: .down)
                else { return nil }
                return (id, min)
            }
            .min { $0.min < $1.min }?
            .id
    }

    func violation(merchantId: String?, amount: BigUInt) -> Violation? {
        guard amount > 0 else { return nil }

        let min: Double?
        let max: Double?
        if let merchantId {
            let limits = limits(for: merchantId)
            min = limits?.min
            max = limits?.max
        } else {
            min = providers.compactMap(\.limits?.min).min()
            max = providers.compactMap(\.limits?.max).max()
        }

        if let min, amount < smallestUnits(min, roundingMode: .down) {
            return .belowMin(message: TKLocales.Ramp.ProviderPicker.minAmount(NSDecimalNumber(value: min).stringValue, currencyCode))
        }
        if let max, amount > smallestUnits(max, roundingMode: .up) {
            return .aboveMax(message: TKLocales.Ramp.ProviderPicker.maxAmount(NSDecimalNumber(value: max).stringValue, currencyCode))
        }
        return nil
    }

    private func smallestUnits(_ value: Double, roundingMode: NSDecimalNumber.RoundingMode) -> BigUInt {
        let multiplier = Decimal(pow(10.0, Double(fractionalDigits)))
        let scaled = Decimal(value) * multiplier
        let rounded = (scaled as NSDecimalNumber).rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: roundingMode,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        )
        return BigUInt(rounded.stringValue) ?? 0
    }
}

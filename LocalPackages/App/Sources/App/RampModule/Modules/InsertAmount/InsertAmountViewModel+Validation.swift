import Foundation
import KeeperCore
import TKLocalize

extension InsertAmountViewModel {
    func amountValidationError() -> InsertAmountError? {
        guard inputAmount > 0 else { return nil }

        let min: Double?
        let max: Double?
        if let selectedMerchant {
            let limits = limitsForMerchant(id: selectedMerchant.id)
            min = limits?.min
            max = limits?.max
        } else if isLayoutLimitsInInputUnits {
            min = minOfMinLimit
            max = maxOfMaxLimit
        } else {
            min = nil
            max = nil
        }

        switch flow {
        case .deposit:
            if let min, inputAmount < fiatToSmallestUnits(Decimal(min), roundingMode: .down) {
                return .belowMin(formattedMessage: TKLocales.Ramp.ProviderPicker.minAmount(NSDecimalNumber(value: min).stringValue, currency.code))
            }
            if let max, inputAmount > fiatToSmallestUnits(Decimal(max), roundingMode: .up) {
                return .aboveMax(formattedMessage: TKLocales.Ramp.ProviderPicker.maxAmount(NSDecimalNumber(value: max).stringValue, currency.code))
            }
        case .withdraw:
            if let min, inputAmount < fiatToSmallestUnits(Decimal(min), roundingMode: .down) {
                return .belowMin(formattedMessage: TKLocales.Ramp.ProviderPicker.minAmount(NSDecimalNumber(value: min).stringValue, assetContext.symbol))
            }
            if let max, inputAmount > fiatToSmallestUnits(Decimal(max), roundingMode: .up) {
                return .aboveMax(formattedMessage: TKLocales.Ramp.ProviderPicker.maxAmount(NSDecimalNumber(value: max).stringValue, assetContext.symbol))
            }
        }

        return nil
    }

    var isInputWithinMinMaxLimit: Bool {
        amountValidationError() == nil
    }

    /// `inputAmount` within `[min, max]` of the merchant's effective limits (nil bound = unbounded).
    /// Comparisons mirror `minAmountText`/`maxAmountText` through the shared `limitsForMerchant`.
    func canMerchantServe(id: String) -> Bool {
        let limits = limitsForMerchant(id: id)
        if let min = limits?.min, inputAmount < fiatToSmallestUnits(Decimal(min), roundingMode: .down) {
            return false
        }
        if let max = limits?.max, inputAmount > fiatToSmallestUnits(Decimal(max), roundingMode: .up) {
            return false
        }
        return true
    }

    /// Whether any loaded merchant can serve `inputAmount` by effective min/max limits.
    /// Uses `availableMerchants` (not `selectableMerchants`): after a non-nil empty
    /// `lastQuotesState`, selectable is empty and would permanently skip `performQuote`.
    var hasServiceableMerchant: Bool {
        availableMerchants.contains { canMerchantServe(id: $0.id) }
    }

    /// Fiat per one asset unit for the converted-amount line. The quote rate only prices the amount
    /// the merchant would actually take: below `min` the server answers with a suggested quote whose
    /// `rate` carries a fixed fee spread over a clamped amount, so out of limits the counter falls
    /// back to the asset's market price instead (TK-3441).
    var convertedAmountRate: Decimal? {
        if let selectedMerchant,
           canMerchantServe(id: selectedMerchant.id),
           let rate = calculateRate(for: selectedMerchant.id),
           rate > 0
        {
            return rate
        }
        return assetContext.marketRate(currencyCode: currency.code)
    }

    var shouldHideConvertedAmount: Bool {
        convertedAmountRate == nil
    }

    var canContinueToProvider: Bool {
        guard let quote = currentMerchantQuote,
              quote.convertedAmount > 0,
              inputAmount == lastCalculatedAmount
        else {
            return false
        }
        if quoteService.createsOrderOnContinue {
            return true
        }
        return quote.widgetURL != nil
    }
}

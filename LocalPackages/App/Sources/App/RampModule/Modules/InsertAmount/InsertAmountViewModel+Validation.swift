import Foundation
import KeeperCore
import TKLocalize

extension InsertAmountViewModel {
    func amountValidationError() -> InsertAmountError? {
        guard inputAmount > 0 else { return nil }

        let min = minOfMinLimit
        let max = maxOfMaxLimit

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
                return .belowMin(formattedMessage: TKLocales.Ramp.ProviderPicker.minAmount(NSDecimalNumber(value: min).stringValue, asset.symbol))
            }
            if let max, inputAmount > fiatToSmallestUnits(Decimal(max), roundingMode: .up) {
                return .aboveMax(formattedMessage: TKLocales.Ramp.ProviderPicker.maxAmount(NSDecimalNumber(value: max).stringValue, asset.symbol))
            }
        }

        return nil
    }

    var isInputWithinMinMaxLimit: Bool {
        amountValidationError() == nil
    }

    var shouldHideConvertedAmount: Bool {
        calculateRate(for: selectedMerchant?.id) == nil
    }

    var canContinueToProvider: Bool {
        currentQuoteWidgetURL != nil && inputAmount == lastCalculatedAmount
    }
}

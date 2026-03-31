import Foundation

public extension RemoteConfiguration {
    var batteryMeanFeesDecimaNumber: NSDecimalNumber? {
        NSDecimalNumber.number(stringValue: batteryMeanFees)
    }

    var batteryReservedAmountDecimalNumber: NSDecimalNumber? {
        NSDecimalNumber.number(stringValue: batteryReservedAmount)
    }

    var batteryMeanFeesPriceSwapDecimaNumber: NSDecimalNumber? {
        NSDecimalNumber.number(stringValue: batteryMeanPriceSwap)
    }

    var batteryMeanFeesPriceJettonDecimaNumber: NSDecimalNumber? {
        NSDecimalNumber.number(stringValue: batteryMeanPriceJetton)
    }

    var batteryMeanFeesPriceNFTDecimaNumber: NSDecimalNumber? {
        NSDecimalNumber.number(stringValue: batteryMeanPriceNFT)
    }

    var batteryMeanPriceTRCMinDecimalNumber: NSDecimalNumber? {
        NSDecimalNumber.number(stringValue: batteryMeanPriceTRCMin) ?? 0.312
    }

    var batteryMeanPriceTRCMaxDecimalNumber: NSDecimalNumber? {
        NSDecimalNumber.number(stringValue: batteryMeanPriceTRCMax) ?? 0.78
    }

    var batteryMaxInputAmountDecimaNumber: NSDecimalNumber {
        NSDecimalNumber.number(stringValue: batteryMaxInputAmount) ?? 3
    }

    var reportAmountDecimalNumber: NSDecimalNumber {
        NSDecimalNumber.number(stringValue: reportAmount) ?? 0.03
    }
}

public extension NSDecimalNumber {
    static func number(stringValue: String?) -> NSDecimalNumber? {
        let number = NSDecimalNumber(string: stringValue)
        guard number != NSDecimalNumber.notANumber else {
            return nil
        }
        return number
    }
}

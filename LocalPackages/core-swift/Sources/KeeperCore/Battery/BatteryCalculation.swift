import BigInt
import Foundation

public struct BatteryCalculation {
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func calculateCharges(tonAmount: BigUInt) -> Int? {
        let convertedAmount = NSDecimalNumber(
            mantissa: UInt64(tonAmount),
            exponent: -Int16(TonInfo.fractionDigits),
            isNegative: false
        )
        return calculateCharges(tonAmount: convertedAmount)
    }

    public func calculateCharges(tonAmount: NSDecimalNumber) -> Int? {
        guard let batteryMeanFees = configuration.batteryMeanFeesDecimaNumber(network: .mainnet) else { return nil }
        let chargesCountDecimal = tonAmount.dividing(by: batteryMeanFees)
        let chargesCountRounded = chargesCountDecimal.rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .up,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        )
        return Int(truncating: chargesCountRounded)
    }

    public func calculateSwapsMinimumChargesAmount(network: Network) -> Int? {
        guard let price = configuration.batteryMeanFeesPriceSwapDecimaNumber(network: network),
              let fee = configuration.batteryMeanFeesDecimaNumber(network: network) else { return nil }
        return calculateTransactionCharges(
            price: price,
            fee: fee
        )
    }

    public func calculateTokenTransferMinimumChargesAmount(network: Network) -> Int? {
        guard let price = configuration.batteryMeanFeesPriceJettonDecimaNumber(network: network),
              let fee = configuration.batteryMeanFeesDecimaNumber(network: network) else { return nil }
        return calculateTransactionCharges(
            price: price,
            fee: fee
        )
    }

    public func calculateNFTTransferMinimumChargesAmount(network: Network) -> Int? {
        guard let price = configuration.batteryMeanFeesPriceNFTDecimaNumber(network: network),
              let fee = configuration.batteryMeanFeesDecimaNumber(network: network) else { return nil }
        return calculateTransactionCharges(
            price: price,
            fee: fee
        )
    }

    public func calculateTRC20MinimumChargesAmount(network: Network) -> Int? {
        guard let price = configuration.batteryMeanFeesPriceTRCMin(network: network),
              let fee = configuration.batteryMeanFeesDecimaNumber(network: network) else { return nil }
        return calculateTransactionCharges(
            price: price,
            fee: fee
        )
    }

    public func calculateTRC20MaximumChargesAmount(network: Network) -> Int? {
        guard let price = configuration.batteryMeanFeesPriceTRCMax(network: network),
              let fee = configuration.batteryMeanFeesDecimaNumber(network: network) else { return nil }
        return calculateTransactionCharges(
            price: price,
            fee: fee
        )
    }

    public func calculateTransactionCharges(
        price: NSDecimalNumber,
        fee: NSDecimalNumber
    ) -> Int {
        return price
            .dividing(by: fee, withBehavior: NSDecimalNumberHandler.dividingRoundBehaviour)
            .rounding(accordingToBehavior: NSDecimalNumberHandler.roundBehaviour)
            .intValue
    }
}

private extension NSDecimalNumberHandler {
    static var dividingRoundBehaviour: NSDecimalNumberHandler {
        return NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 20,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
    }

    static var roundBehaviour: NSDecimalNumberHandler {
        return NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
    }
}

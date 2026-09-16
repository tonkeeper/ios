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
        return Self.roundCharges(tonAmount.dividing(by: batteryMeanFees))
    }

    /// Charges are rounded away from zero: a fractional remainder still costs a whole charge, and
    /// a refund deficit reports its full magnitude instead of understating it.
    static func roundCharges(_ count: NSDecimalNumber) -> Int {
        let isNegative = count.compare(NSDecimalNumber.zero) == .orderedAscending
        let rounded = count.rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: isNegative ? .down : .up,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        )
        return Int(truncating: rounded)
    }

    /// Charges the wallet can spend. A refund can push the service balance below zero, and a
    /// negative balance buys nothing — it is not a debt any flow may spend against.
    public func calculateAvailableCharges(balance: BatteryBalance) -> Int? {
        calculateCharges(tonAmount: balance.balanceDecimalNumber).map { max($0, 0) }
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

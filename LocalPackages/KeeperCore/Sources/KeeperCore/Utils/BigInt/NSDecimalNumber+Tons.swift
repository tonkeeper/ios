import BigInt
import Foundation

public extension NSDecimalNumber {
    func toNanoTons() -> NSDecimalNumber {
        multiplying(byPowerOf10: Int16(TonInfo.fractionDigits))
    }

    func toNanoTonsBigUInt() -> BigUInt? {
        let nano = toNanoTons().rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .up,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        )
        return BigUInt(nano.stringValue)
    }
}

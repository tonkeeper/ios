import BigInt
import Foundation

extension BigUInt {
    func decimalAmount(decimals: Int) -> Decimal? {
        guard let integer = Decimal(string: description) else {
            return nil
        }
        let divisor = Decimal(sign: .plus, exponent: decimals, significand: 1)
        return integer / divisor
    }
}

import Foundation
import BigInt

public struct TokenRate: Equatable {
    public static func == (lhs: TokenRate, rhs: TokenRate) -> Bool {
        lhs.rate.rate == rhs.rate.rate && lhs.rate.currency == rhs.rate.currency
    }
    
    let rate: Rates.Rate
    let ratePlainBigInt: BigUInt
    let rateNormalizedBigInt: BigUInt
    
    init(rate: Rates.Rate) {
        self.rate = rate
        
        let p = rate.rate.plainNumberString()
        ratePlainBigInt = BigUInt(stringLiteral: p.string)
        rateNormalizedBigInt = BigUInt(stringLiteral: "1" + String(repeating: "0", count: p.digits))
    }
}

private extension Decimal {
    func plainNumberString() -> (string: String, digits: Int) {
        if self.isZero {
            return ("0", 0)
        }

        let str = "\(self)"
        var resultStr = ""
        var i = 0

        var afterInt = false
        var afterPoint = false

        for char in str {
            if char == "." {
                afterPoint = true
                continue
            }

            if char != "0" {
                afterInt = true
            }

            if afterPoint {
                i += 1
            }

            if afterInt && char != "." {
                resultStr += String(char)
            }
        }
        return (resultStr, i)
    }
}

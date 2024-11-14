import Foundation
import BigInt

public extension NSDecimalNumber {
  static func fromBigUInt(value: BigUInt, decimals: Int) -> NSDecimalNumber {
    let string = value.description
    let fractional = String(string.suffix(decimals))
    let int: String = {
      let int = String(string.prefix(max(0, string.count - decimals)))
      if int.isEmpty {
        return "0"
      } else {
        return int
      }
    }()
    let padSize =  max(0, decimals - fractional.count)
    let paddedFractional = String(repeating: "0", count: padSize) + fractional
    return NSDecimalNumber(string: "\(int).\(paddedFractional)")
  }
}

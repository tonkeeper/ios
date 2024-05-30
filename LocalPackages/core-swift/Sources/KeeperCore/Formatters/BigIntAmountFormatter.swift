import Foundation
import BigInt

public struct BigIntAmountFormatter {

  public let groupSeparator: String
  public var fractionalSeparator: String {
    String.fractionalSeparator ?? "."
  }

  public init(groupSeparator: String? = nil) {
    if let separator = groupSeparator {
      self.groupSeparator = separator
    } else {
      self.groupSeparator = String.defaultGroupSeparator
    }
  }
  
  enum Error: Swift.Error {
    case invalidInput(_ input: String)
  }
  
  public func format(amount: BigUInt,
                     fractionDigits: Int,
                     maximumFractionDigits: Int) -> String {
    guard !amount.isZero else { return "0" }
    let initialString = amount.description
    if initialString.count < fractionDigits {
      let significantLength = initialString.count
      let nonSignificantLength = fractionDigits - significantLength
      let significantPart = initialString.prefix(maximumFractionDigits).filter { $0 != "0" }
      let string = String(repeating: "0", count: nonSignificantLength) + significantPart
      return "0" + (.fractionalSeparator ?? ".") + string
    } else {
      let fractional = String(initialString.suffix(fractionDigits))
      let fractionalLength = min(fractionDigits, maximumFractionDigits)
      let fractionalResult = String(fractional[fractional.startIndex..<fractional.index(fractional.startIndex, offsetBy: fractionalLength)])
        .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
      let integer = String(initialString.prefix(initialString.count - fractional.count))
      let separatedInteger = groups(string: integer.isEmpty ? "0" : integer, size: .groupSize).joined(separator: groupSeparator)
      var result = separatedInteger
      if fractionalResult.count > 0 {
        result += (.fractionalSeparator ?? ".") + fractionalResult
      }
      return result
    }
  }
  
  public func bigInt(string: String, targetFractionalDigits: Int) throws -> (amount: BigInt, fractionalDigits: Int) {
    guard !string.isEmpty else { throw Error.invalidInput(string) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = string.components(separatedBy: fractionalSeparator)
    guard components.count < 3 else { throw Error.invalidInput(string) }
    
    var fractionalDigits = 0
    if components.count == 2 {
      let fractionalString = components[1]
      fractionalDigits = fractionalString.count
    }
    let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
    let bigIntValue = BigInt(stringLiteral: components.joined() + zeroString)
    return (bigIntValue, targetFractionalDigits)
  }
}

private extension BigIntAmountFormatter {
  func groups(string: String, size: Int) -> [String] {
    guard string.count > size else { return [string] }
    let groupBoundaries = stride(from: 0, to: string.count, by: size) + [string.count]
    return (0..<groupBoundaries.count - 1)
      .map { groupBoundaries[$0]..<groupBoundaries[$0 + 1] }.reversed()
      .map {
        let leftIndex = string.index(string.endIndex, offsetBy: -$0.upperBound)
        let righIndex = string.index(string.endIndex, offsetBy: -$0.lowerBound)
        return String(string[leftIndex..<righIndex])
      }
  }
}

private extension Int {
  static let groupSize = 3
}

private extension String {
  static let defaultGroupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}

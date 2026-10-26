@preconcurrency import BigInt
import Foundation

enum PerpsFundingAmountError: Error, Equatable {
    case malformed(String)
    case tooPrecise(String)
    case outOfRange(String)
}

/// Amounts that end up inside a signature or a calldata. Everything here is string and
/// integer work: a Double or a locale-aware formatter could change what the wallet signs.
enum PerpsFundingAmount {
    static let usdcDecimals = 6
    /// The gateway accepts less and Lighter then never credits it.
    static let gatewayMinimumUsdcUnits = BigUInt(1_000_000)

    /// Integer units as the registration declares them: plain digits, at most `decimals`
    /// fraction digits, no exponent, no grouping, no locale separator.
    static func declaredAmount(units: BigUInt, decimals: Int) -> String {
        guard decimals > 0 else { return units.description }
        let digits = units.description
        let padded = String(repeating: "0", count: max(0, decimals + 1 - digits.count)) + digits
        let integerPart = String(padded.prefix(padded.count - decimals))
        var fraction = Substring(padded.suffix(decimals))
        while fraction.hasSuffix("0") {
            fraction = fraction.dropLast()
        }
        return fraction.isEmpty ? integerPart : "\(integerPart).\(fraction)"
    }

    static func units(declaredAmount: String, decimals: Int) throws(PerpsFundingAmountError) -> BigUInt {
        let parts = declaredAmount.split(separator: ".", omittingEmptySubsequences: false)
        guard !declaredAmount.isEmpty, parts.count <= 2 else {
            throw PerpsFundingAmountError.malformed(declaredAmount)
        }
        let integerPart = String(parts[0])
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard !integerPart.isEmpty || !fraction.isEmpty,
              integerPart.allSatisfy(\.isASCIIDigit),
              fraction.allSatisfy(\.isASCIIDigit)
        else {
            throw PerpsFundingAmountError.malformed(declaredAmount)
        }
        guard fraction.count <= decimals else {
            throw PerpsFundingAmountError.tooPrecise(declaredAmount)
        }
        let padded = integerPart + fraction + String(repeating: "0", count: decimals - fraction.count)
        guard let units = BigUInt(padded, radix: 10) else {
            throw PerpsFundingAmountError.malformed(declaredAmount)
        }
        return units
    }

    /// Smallest-unit integers as the API writes them: plain digits, no sign, no exponent,
    /// no separators. `BigUInt` alone would accept forms the contract does not.
    static func integerUnits(_ value: String) throws(PerpsFundingAmountError) -> BigUInt {
        guard !value.isEmpty,
              value.allSatisfy(\.isASCIIDigit),
              let units = BigUInt(value, radix: 10)
        else {
            throw PerpsFundingAmountError.malformed(value)
        }
        return units
    }

    /// The venue's payloads carry a signed 64-bit amount, so a value the wallet could hold
    /// but the payload cannot express has to be refused before signing.
    static func int64Units(_ units: BigUInt) throws(PerpsFundingAmountError) -> Int64 {
        guard units <= BigUInt(Int64.max) else {
            throw PerpsFundingAmountError.outOfRange(units.description)
        }
        return Int64(units)
    }
}

private extension Character {
    var isASCIIDigit: Bool {
        isASCII && isNumber
    }
}

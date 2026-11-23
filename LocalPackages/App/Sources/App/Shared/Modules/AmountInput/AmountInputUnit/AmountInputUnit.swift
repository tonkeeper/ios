import Foundation

protocol AmountInputUnit {
    var inputSymbol: AmountInputSymbol { get }
    var fractionalDigits: Int { get }
    var symbol: String { get }
    var conversionRounding: AmountInputConversionRounding { get }
}

extension AmountInputUnit {
    var conversionRounding: AmountInputConversionRounding {
        .nearest
    }
}

enum AmountInputConversionRounding {
    case nearest
    case wholeUnits

    var intoUnitMode: NSDecimalNumber.RoundingMode {
        switch self {
        case .nearest:
            .plain
        case .wholeUnits:
            .down
        }
    }

    var outOfUnitMode: NSDecimalNumber.RoundingMode {
        switch self {
        case .nearest:
            .plain
        case .wholeUnits:
            .up
        }
    }
}

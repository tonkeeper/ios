import Foundation
@testable import Perps
import PerpsModels

/// The production glyphs come from `AmountFormatter`, which lives behind `ChainKit` and
/// therefore outside this package. These assertions compare the feature's output against
/// the same formatter that produced it, so a deterministic stand-in keeps them meaningful.
struct PerpsTestAmountFormatting: PerpsAmountFormatting {
    func usdCompact(_ value: Decimal) -> String {
        "$\(plain(value))"
    }

    func usdExact(_ value: Decimal) -> String {
        "$\(plain(value))"
    }

    func signedPercent(_ value: Decimal) -> String {
        "\(value < 0 ? "" : "+")\(plain(value))%"
    }

    func fundingExact(_ value: Decimal) -> String {
        plain(value)
    }

    func exact(_ value: Decimal) -> String {
        plain(value)
    }

    func compact(_ value: Decimal) -> String {
        plain(value)
    }

    private func plain(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

extension PerpsFormatting {
    static let test = PerpsFormatting(amounts: PerpsTestAmountFormatting())
}

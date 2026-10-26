import Foundation
import PerpsModels

/// A stand-in for the `ChainKit` formatter the app injects, close enough to its glyphs
/// for a preview to read like the design.
private struct PerpsPreviewAmountFormatting: PerpsAmountFormatting {
    func usdCompact(_ value: Decimal) -> String {
        "$" + Self.string(value, maximumFractionDigits: 2)
    }

    func usdExact(_ value: Decimal) -> String {
        usdCompact(value)
    }

    func signedPercent(_ value: Decimal) -> String {
        (value < 0 ? "−" : "+") + Self.string(abs(value), maximumFractionDigits: 2) + "%"
    }

    func fundingExact(_ value: Decimal) -> String {
        Self.string(value, maximumFractionDigits: 8)
    }

    func exact(_ value: Decimal) -> String {
        Self.string(value, maximumFractionDigits: 8)
    }

    func compact(_ value: Decimal) -> String {
        Self.string(value, maximumFractionDigits: value < 1 ? 8 : 2)
    }

    private static func string(_ value: Decimal, maximumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = "."
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

extension PerpsFormatting {
    static let preview = PerpsFormatting(amounts: PerpsPreviewAmountFormatting())
}

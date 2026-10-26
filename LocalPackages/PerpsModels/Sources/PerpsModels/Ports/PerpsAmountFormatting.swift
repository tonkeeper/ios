import Foundation

/// The only formatting the perps screens cannot do themselves: fiat and percent glyphs
/// come out of `ChainKit`, which the feature package must not reach. Everything built on
/// top of these six primitives — signs, symbols, leverage suffixes, dates — is plain
/// Foundation and stays in the feature.
public protocol PerpsAmountFormatting {
    func usdCompact(_ value: Decimal) -> String
    func usdExact(_ value: Decimal) -> String
    func signedPercent(_ value: Decimal) -> String
    func fundingExact(_ value: Decimal) -> String
    func exact(_ value: Decimal) -> String
    /// The wallet's balance style: a small amount of a dear coin keeps its significant digits.
    func compact(_ value: Decimal) -> String
}

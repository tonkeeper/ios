import Foundation
import KeeperCore
import Perps
import PerpsModels

extension PerpsFormatting {
    static let live = PerpsFormatting(amounts: PerpsLiveAmountFormatting())
}

/// `AmountFormatter` reaches ChainKit for the fiat and percent glyphs, so the feature
/// package gets these six results rather than the formatter itself.
struct PerpsLiveAmountFormatting: PerpsAmountFormatting {
    private let exactFormatter = AmountFormatter(configuration: .init())
    private let amountFormatter = AmountFormatter(configuration: .init())
    private let signedFormatter = AmountFormatter(configuration: .init(signPolicy: .always))
    private let fundingFormatter = AmountFormatter(configuration: .init(signPolicy: .negativeOnly))

    func usdCompact(_ value: Decimal) -> String {
        amountFormatter.format(decimal: value, accessory: .fiat(Currency.USD), style: .compact)
    }

    func usdExact(_ value: Decimal) -> String {
        amountFormatter.format(decimal: value, accessory: .fiat(Currency.USD), style: .exactValue)
    }

    func signedPercent(_ value: Decimal) -> String {
        signedFormatter.format(decimal: value, style: .percent)
    }

    func fundingExact(_ value: Decimal) -> String {
        fundingFormatter.format(decimal: value, style: .exactValue)
    }

    func exact(_ value: Decimal) -> String {
        exactFormatter.format(decimal: value, style: .exactValue)
    }

    func compact(_ value: Decimal) -> String {
        amountFormatter.format(decimal: value, style: .compact)
    }
}

import BigInt
import Foundation
import KeeperCore
import Perps
import PerpsModels

extension PerpsFormatting {
    static let live = PerpsFormatting(amounts: PerpsLiveAmountFormatting(), locale: AmountFormatter.Configuration.defaultLocale)

    static func live(appSettingsStore: AppSettingsStore) -> PerpsFormatting {
        PerpsFormatting(amounts: PerpsLiveAmountFormatting(), locale: AmountFormatter.Configuration.defaultLocale) { [weak appSettingsStore] in
            appSettingsStore?.getState().isSecureMode == true ? .secureModeValueShort : nil
        }
    }
}

/// `AmountFormatter` reaches ChainKit for the fiat and percent glyphs, so the feature
/// package gets these results rather than the formatter itself.
struct PerpsLiveAmountFormatting: PerpsAmountFormatting {
    private let exactFormatter = AmountFormatter(configuration: .init())
    private let amountFormatter = AmountFormatter(configuration: .init())
    private let signedFormatter = AmountFormatter(configuration: .init(signPolicy: .always, space: ""))
    private let fundingFormatter = AmountFormatter(configuration: .init(signPolicy: .negativeOnly, space: ""))
    private let fixedFormatter = AmountFormatter(configuration: .init(trimTrailingZeros: false))

    func usdCompact(_ value: Decimal) -> String {
        amountFormatter.format(decimal: value, accessory: .fiat(Currency.USD), style: .compact)
    }

    func usdFixed(_ value: Decimal, fractionDigits: Int) -> String {
        fixed(value, fractionDigits: fractionDigits, accessory: .fiat(Currency.USD))
    }

    func fixed(_ value: Decimal, fractionDigits: Int) -> String {
        fixed(value, fractionDigits: fractionDigits, accessory: .none)
    }

    private func fixed(_ value: Decimal, fractionDigits: Int, accessory: AmountAccessoryType) -> String {
        var scaled = abs(value) * pow(10, fractionDigits)
        var units = Decimal()
        NSDecimalRound(&units, &scaled, 0, .plain)
        return fixedFormatter.format(
            amount: BigUInt(units.description) ?? 0,
            fractionDigits: fractionDigits,
            accessory: accessory,
            style: .exactValue
        )
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

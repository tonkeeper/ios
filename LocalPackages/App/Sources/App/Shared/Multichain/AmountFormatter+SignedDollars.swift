import BigInt
import KeeperCore
import TKLocalize

extension AmountFormatter {
    /// "+ $10.25": the formatter's own sign would land after a leading "$", so it is prefixed here.
    /// Call it on an unsigned formatter.
    func signedDollars(
        amount: BigUInt,
        fractionDigits: Int,
        isNegative: Bool,
        style: AmountDisplayStyle
    ) -> String {
        let dollars = format(amount: amount, fractionDigits: fractionDigits, accessory: .fiat(Currency.USD), style: style)
        guard !amount.isZero else { return dollars }
        return (isNegative ? String.Symbol.minus : String.Symbol.plus) + config.space + dollars
    }
}

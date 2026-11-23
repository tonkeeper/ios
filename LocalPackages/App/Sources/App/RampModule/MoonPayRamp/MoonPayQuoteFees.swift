import AppUI
import Foundation
import MoonPay
import TKLocalize

/// The fees of a MoonPay quote as the payment status and the price details show them, so both
/// list the same rows with the same amounts.
enum MoonPayQuoteFees {
    /// The fees both the rows and the total show, keyed in lower case:
    /// - without the deprecated `partner`, which repeats `ecosystem` and MoonPay says to leave out
    ///   so it is not counted twice;
    /// - only in the currency paid, which MoonPay quotes every fee in, so a row never shows an
    ///   amount the total leaves out;
    /// - parsed once, so every row and the total print the same numbers, and a fee whose amount
    ///   does not parse is shown nowhere rather than as a row the total ignores;
    /// - with keys that differ only in case summed, so the result does not depend on the order
    ///   the dictionary happens to iterate in.
    static func amounts(of quote: MoonPayBuyQuote) -> [String: Decimal] {
        let code = quote.source.asset.code?.lowercased()
        let kept = (quote.fees ?? [:]).compactMap { key, money -> (String, Decimal)? in
            let key = key.lowercased()
            guard key != deprecatedPartnerFee,
                  money.asset.code?.lowercased() == code,
                  let amount = money.amount.flatMap({ Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) })
            else { return nil }
            return (key, amount)
        }
        return Dictionary(kept, uniquingKeysWith: +)
    }

    static func totalText(of quote: MoonPayBuyQuote) -> String {
        text(amounts(of: quote).values.reduce(0, +), quote: quote)
    }

    /// Rows in the order shown, then one row for every other kind, such as `defi`, so the rows add
    /// up to the total. MoonPay asks for no DeFi Fee row of its own.
    static func rows(of quote: MoonPayBuyQuote) -> [MoonPayPaymentStatusViewState.SummaryRow] {
        typealias Status = TKLocales.Ramp.Moonpay.Status
        let fees = amounts(of: quote)
        let named: [(key: String, title: String)] = [
            ("moonpay", Status.feeMoonpay),
            // Keeper's own fee: MoonPay calls it the ecosystem fee.
            ("ecosystem", Status.feeEcosystem),
            ("network", Status.feeNetwork),
        ]
        let rows: [MoonPayPaymentStatusViewState.SummaryRow] = named.compactMap { key, title in
            fees[key].map { .init(id: key, title: title, value: text($0, quote: quote)) }
        }
        let others = fees.filter { key, _ in !named.contains { $0.key == key } }.values
        guard !others.isEmpty else { return rows }
        return rows + [.init(id: otherFeesID, title: Status.feeOther, value: text(others.reduce(0, +), quote: quote))]
    }

    private static let deprecatedPartnerFee = "partner"
    private static let otherFeesID = "other"

    private static func text(_ amount: Decimal, quote: MoonPayBuyQuote) -> String {
        MoonPayPaymentStatusViewModel.paidText(amount, code: quote.source.asset.code)
    }
}

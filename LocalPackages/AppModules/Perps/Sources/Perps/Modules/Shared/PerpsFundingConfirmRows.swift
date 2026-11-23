import Foundation
import TKLocalize

enum PerpsFundingConfirmRows {
    static func arrivalTime(seconds: Int, hint: String? = nil) -> PerpsTradeConfirmRow {
        PerpsTradeConfirmRow(
            id: .arrivalTime,
            title: TKLocales.Perps.Funding.arrivalTime,
            value: TKLocales.Ramp.Deposit.upToMin(max(1, Int((Double(seconds) / 60).rounded(.up)))),
            subValue: nil,
            titleHint: hint
        )
    }

    static func networkFee(
        title: String,
        fee: String?,
        symbol: String,
        usd: Decimal?,
        format: PerpsFormatting
    ) -> PerpsTradeConfirmRow {
        guard let fee else {
            return PerpsTradeConfirmRow(id: .networkFee, title: title, value: PerpsFundingText.missing, subValue: nil, tone: .tertiary)
        }
        let token = PerpsFundingAmountInput.decimal(fee).map { format.tokenCompact($0, symbol: symbol) } ?? "\(fee) \(symbol)"
        guard let usd else {
            return PerpsTradeConfirmRow(id: .networkFee, title: title, value: "≈ \(token)", subValue: nil)
        }
        return PerpsTradeConfirmRow(
            id: .networkFee,
            title: title,
            value: "≈ \(format.usd(NSDecimalNumber(decimal: usd).doubleValue))",
            subValue: symbol == "USDC" || symbol == "USD" ? nil : token
        )
    }

    /// Said when fees take at least 15% of the dollars `amount` puts in: a larger amount spreads the same fee thinner.
    static func highFeeNotice(fee: Decimal?, of amount: Decimal?) -> String? {
        guard let fee, let amount, amount > 0, fee / amount >= 0.15 else { return nil }
        return TKLocales.Perps.Funding.highFee(Int(NSDecimalNumber(decimal: fee / amount * 100).doubleValue.rounded()))
    }

    static func usd(_ amount: String, price: Decimal?, format: PerpsFormatting) -> String? {
        guard let price, let value = PerpsFundingAmountInput.decimal(amount) else { return nil }
        return format.usd(NSDecimalNumber(decimal: value * price).doubleValue)
    }
}

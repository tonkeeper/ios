import BigInt
import Foundation
import TonAPI
import TonSwift

enum SignRawRiskFiatValue {
    static func serverTotal(risk: TonAPI.Components.Schemas.Risk, transferType: TransferType) -> Double? {
        guard !transferType.isBattery,
              let value = risk.totalEquivalent,
              value.isFinite, value >= 0
        else { return nil }
        return Double(value)
    }

    static func calculate(risk: TonAPI.Components.Schemas.Risk, rates: Rates, currency: Currency) -> Double? {
        guard risk.gram >= 0, risk.nfts.isEmpty else { return nil }
        let converter = RateConverter()
        var total = Decimal.zero
        if risk.gram > 0 {
            guard let rate = rates.ton.first(where: { $0.currency == currency }),
                  !rate.rate.isNaN, rate.rate > 0
            else { return nil }
            total += converter.convertToDecimal(
                amount: BigUInt(risk.gram),
                amountFractionLength: TonInfo.fractionDigits,
                rate: rate
            )
        }
        for jetton in risk.jettons {
            guard let quantity = BigUInt(jetton.quantity) else { return nil }
            guard quantity > 0 else { continue }
            guard let address = try? Address.parse(jetton.jetton.address),
                  let rate = rates.jettonRates.first(where: { (try? Address.parse($0.key)) == address })?
                  .value.first(where: { $0.currency == currency }),
                  !rate.rate.isNaN, rate.rate > 0,
                  (0 ... 255).contains(jetton.jetton.decimals)
            else { return nil }
            total += converter.convertToDecimal(
                amount: quantity,
                amountFractionLength: jetton.jetton.decimals,
                rate: rate
            )
        }
        let value = NSDecimalNumber(decimal: total).doubleValue
        return value.isFinite && value >= 0 ? value : nil
    }
}

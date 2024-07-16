import Foundation
import BigInt
import KeeperCore

struct TokenDetailsMapper {
  private let amountFormatter: AmountFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let rateConverter: RateConverter
  
  init(amountFormatter: AmountFormatter,
       decimalAmountFormatter: DecimalAmountFormatter,
       rateConverter: RateConverter) {
    self.amountFormatter = amountFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
    self.rateConverter = rateConverter
  }
  
  func mapTonBalance(tonBalance: ConvertedTonBalance, currency: Currency) -> (tokenAmount: String, convertedAmount: String?) {
    let bigUIntAmount = BigUInt(tonBalance.tonBalance.amount)
    let amount = amountFormatter.formatAmount(
      bigUIntAmount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      symbol: TonInfo.symbol
    )
    let converted = decimalAmountFormatter.format(
      amount: tonBalance.converted,
      maximumFractionDigits: 2,
      currency: currency
    )
    
    return (amount, converted)
  }
  
  func mapJettonBalance(jettonBalance: ConvertedJettonBalance, currency: Currency) -> (tokenAmount: String, convertedAmount: String?) {
    let amount = amountFormatter.formatAmount(
      jettonBalance.jettonBalance.quantity,
      fractionDigits: jettonBalance.jettonBalance.item.jettonInfo.fractionDigits,
      maximumFractionDigits: jettonBalance.jettonBalance.item.jettonInfo.fractionDigits,
      symbol: jettonBalance.jettonBalance.item.jettonInfo.symbol
    )
    let converted = decimalAmountFormatter.format(
      amount: jettonBalance.converted,
      maximumFractionDigits: 2,
      currency: currency
    )
    return (amount, converted)
  }
  
  func mapTonBalance(amount: Int64,
                     tonRates: [Rates.Rate],
                     currency: Currency) -> (tokenAmount: String, convertedAmount: String?) {
    let bigUIntAmount = BigUInt(amount)
    let amount = amountFormatter.formatAmount(
      bigUIntAmount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      symbol: TonInfo.symbol
    )
    
    var convertedAmount: String?
    if let rate = tonRates.first(where: { $0.currency == currency }) {
      let converted = rateConverter.convert(
        amount: bigUIntAmount,
        amountFractionLength: TonInfo.fractionDigits,
        rate: rate
      )
      convertedAmount = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
    }
    
    return (amount, convertedAmount)
  }
  
  func mapJettonBalance(jettonBalance: JettonBalance,
                        currency: Currency) -> (tokenAmount: String, convertedAmount: String?) {
    let amount = amountFormatter.formatAmount(
      jettonBalance.quantity,
      fractionDigits: jettonBalance.item.jettonInfo.fractionDigits,
      maximumFractionDigits: jettonBalance.item.jettonInfo.fractionDigits,
      symbol: jettonBalance.item.jettonInfo.symbol
    )
    
    var convertedAmount: String?
    if let rate = jettonBalance.rates[currency] {
      let converted = rateConverter.convert(
        amount: jettonBalance.quantity,
        amountFractionLength: jettonBalance.item.jettonInfo.fractionDigits,
        rate: rate
      )
      convertedAmount = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
    }
    return (amount, convertedAmount)
  }
}

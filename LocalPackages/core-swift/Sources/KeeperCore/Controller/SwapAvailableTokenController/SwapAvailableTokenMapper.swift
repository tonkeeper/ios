import Foundation
import BigInt
import TonSwift

public struct AvailableTokenModelItem {
  public let token: Token
  public let amount: String?
  public let convertedAmount: String?
}

struct SwapAvailableTokenMapper {

  private let amountFormatter: AmountFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let rateConverter: RateConverter
  private let dateFormatter: DateFormatter
  
  init(amountFormatter: AmountFormatter,
       decimalAmountFormatter: DecimalAmountFormatter,
       rateConverter: RateConverter,
       dateFormatter: DateFormatter) {
    self.amountFormatter = amountFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
    self.rateConverter = rateConverter
    self.dateFormatter = dateFormatter
  }

  func mapTon(balance: TonBalance, rates: [Rates.Rate], currency: Currency) -> AvailableTokenModelItem {
    let bigUIntAmount = BigUInt(balance.amount)
    let amount = amountFormatter.formatAmount(
      bigUIntAmount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2
    )
    var convertedAmount: String?
    if let rate = rates.first(where: { $0.currency == currency }) {
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
    return AvailableTokenModelItem(
      token: .ton,
      amount: amount,
      convertedAmount: convertedAmount)
  }

  func mapJettons(jettonsBalance: [JettonBalance],
                  jettonsRates: [Rates.JettonRate],
                  currency: Currency,
                  excludeTokenAddress: Address?) -> ([AvailableTokenModelItem]) {
    jettonsBalance.compactMap { jettonBalance in
      if jettonBalance.item.walletAddress == excludeTokenAddress { return nil }
      guard !jettonBalance.quantity.isZero else { return nil }
      let jettonRates = jettonsRates.first(where: { $0.jettonInfo == jettonBalance.item.jettonInfo })
      return mapJetton(
        jettonBalance: jettonBalance,
        jettonRates: jettonRates,
        currency: currency
      )
    }
  }
  
  private func mapJetton(jettonBalance: JettonBalance,
                 jettonRates: Rates.JettonRate?,
                 currency: Currency) -> AvailableTokenModelItem {
    let amount = amountFormatter.formatAmount(
      jettonBalance.quantity,
      fractionDigits: jettonBalance.item.jettonInfo.fractionDigits,
      maximumFractionDigits: 2
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
    return AvailableTokenModelItem(
      token: .jetton(jettonBalance.item),
      amount: amount,
      convertedAmount: convertedAmount)
  }
}

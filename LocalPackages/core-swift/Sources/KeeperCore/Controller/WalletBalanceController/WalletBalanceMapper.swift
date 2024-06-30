import Foundation
import BigInt

struct WalletBalanceMapper {
  
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
  
  func makeUpdatedDate(_ date: Date) -> String {
    dateFormatter.dateFormat = "MMM d, HH:mm"
    return dateFormatter.string(from: date)
  }
  
  func mapTotalBalance(_ totalBalance: TotalBalance, currency: Currency) -> String {
    ""
//    amountFormatter.formatAmountWithoutFractionIfThousand(
//      totalBalance.amount,
//      fractionDigits: totalBalance.fractionalDigits,
//      maximumFractionDigits: 2,
//      currency: currency
//    )
  }
  
  func mapBalance(balance: Balance,
                  rates: Rates,
                  currency: Currency) -> WalletBalanceItemsModel {
    let tonItem = mapTon(
      tonBalance: balance.tonBalance,
      tonRates: rates.ton,
      currency: currency
    )
    
    let jettonItems = mapJettons(
      jettonsBalance: balance.jettonsBalance,
      jettonsRates: rates.jettonsRates,
      currency: currency
    )
    
    return WalletBalanceItemsModel(tonItems: [tonItem], jettonsItems: jettonItems)
  }
  
  func mapTon(tonBalance: TonBalance,
              tonRates: [Rates.Rate],
              currency: Currency) -> WalletBalanceItemsModel.Item {
    let bigUIntAmount = BigUInt(tonBalance.amount)
    let amount = amountFormatter.formatAmount(
      bigUIntAmount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2
    )
    
    var price: String?
    var convertedAmount: String?
    var diff: String?
    
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
      price = decimalAmountFormatter.format(
        amount: rate.rate,
        currency: currency
      )
      diff = rate.diff24h == "0" ? nil : rate.diff24h
    }
    
    return WalletBalanceItemsModel.Item(
      identifier: .tonIdentifier,
      token: .ton,
      image: .ton,
      title: TonInfo.name,
      price: price,
      rateDiff: diff,
      amount: amount,
      convertedAmount: convertedAmount,
      verification: .whitelist,
      hasPrice: true)
  }
  
  func mapJettons(jettonsBalance: [JettonBalance],
                  jettonsRates: [Rates.JettonRate],
                  currency: Currency) -> [WalletBalanceItemsModel.Item] {
    var unverified = [JettonBalance]()
    var verified = [JettonBalance]()
    for jettonBalance in jettonsBalance {
      switch jettonBalance.item.jettonInfo.verification {
      case .whitelist:
        verified.append(jettonBalance)
      default:
        unverified.append(jettonBalance)
      }
    }
    
    return (verified + unverified)
      .compactMap { jettonBalance in
        guard !jettonBalance.quantity.isZero else { return nil }
        let jettonRates = jettonsRates.first(where: { $0.jettonInfo == jettonBalance.item.jettonInfo })
        return mapJetton(
          jettonBalance: jettonBalance,
          jettonRates: jettonRates,
          currency: currency
        )
      }
  }
  
  func mapJetton(jettonBalance: JettonBalance,
                 jettonRates: Rates.JettonRate?,
                 currency: Currency) -> WalletBalanceItemsModel.Item {
    let amount = amountFormatter.formatAmount(
      jettonBalance.quantity,
      fractionDigits: jettonBalance.item.jettonInfo.fractionDigits,
      maximumFractionDigits: 2
    )
    
    var price: String?
    var convertedAmount: String?
    var diff: String?
    var hasPrice = false
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
      price = decimalAmountFormatter.format(
        amount: rate.rate,
        currency: currency
      )
      diff = rate.diff24h == "0" ? nil : rate.diff24h
      hasPrice = !rate.rate.isZero
    }
    return WalletBalanceItemsModel.Item(
      identifier: jettonBalance.item.jettonInfo.address.toRaw(),
      token: .jetton(jettonBalance.item),
      image: .url(jettonBalance.item.jettonInfo.imageURL),
      title: jettonBalance.item.jettonInfo.symbol ?? jettonBalance.item.jettonInfo.name,
      price: price,
      rateDiff: diff,
      amount: amount,
      convertedAmount: convertedAmount,
      verification: jettonBalance.item.jettonInfo.verification,
      hasPrice: hasPrice
    )
  }
}

private extension String {
  static let tonIdentifier = UUID().uuidString
}

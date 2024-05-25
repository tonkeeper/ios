import Foundation
import TKCore
import KeeperCore
import BigInt

class ExchangeConfirmationConverter {
  typealias Amount = (amount: BigUInt, fractionLength: Int)
  
  private let bigIntAmountFormatter: BigIntAmountFormatter
  private let rateConverter: RateConverter
  private let rate: Decimal
  
  private (set) var tonAmount: Amount = (0, 0)
  private (set) var fiatAmount: Amount = (0, 0)
  private (set) var tonInput: String = ""
  private (set) var fiatInput: String = ""
  
  init(
    bigIntAmountFormatter: BigIntAmountFormatter,
    rateConverter: RateConverter,
    rate: Decimal
  ) {
    self.bigIntAmountFormatter = bigIntAmountFormatter
    self.rateConverter = rateConverter
    self.rate = rate
  }
  
  func setup(transactionAmountModel: TransactionAmountModel) {
    switch transactionAmountModel.type {
    case .buy:
      // FIAT -> TON
      tonAmount = (transactionAmountModel.amount, TonInfo.fractionDigits)
      fiatAmount = rateConverter.convert(
        amount: transactionAmountModel.amount,
        amountFractionLength: TonInfo.fractionDigits,
        rate: rate
      )
    case .sell:
      // TON -> FIAT
      fiatAmount = (transactionAmountModel.amount, TonInfo.fractionDigits)
      tonAmount = rateConverter.convert(
        amount: transactionAmountModel.amount,
        amountFractionLength: TonInfo.fractionDigits,
        rate: 1/rate
      )
    }
    
    updateStrings()
  }
  
  func updateTonInput(_ input: String) {
    let ton = convertInputStringToAmount(input: input, targetFractionalDigits: TonInfo.fractionDigits)
    tonAmount = (ton.amount, ton.fractionalDigits)
    fiatAmount = rateConverter.convert(
      amount: ton.amount,
      amountFractionLength: ton.fractionalDigits,
      rate: rate
    )
    
    updateStrings()
  }
  
  func updateFiatInput(_ input: String) {
    let fiat = convertInputStringToAmount(input: input, targetFractionalDigits: TonInfo.fractionDigits)
    fiatAmount = (fiat.amount, fiat.fractionalDigits)
    tonAmount = rateConverter.convert(
      amount: fiatAmount.amount,
      amountFractionLength: TonInfo.fractionDigits,
      rate: 1/rate
    )
    
    updateStrings()
  }
  
  private func updateStrings() {
    tonInput = bigIntAmountFormatter.format(amount: tonAmount.amount, fractionDigits: tonAmount.fractionLength, maximumFractionDigits: 2)
    
    fiatInput = bigIntAmountFormatter.format(amount: fiatAmount.amount, fractionDigits: fiatAmount.fractionLength, maximumFractionDigits: 2)
  }
  
  private func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    do {
      let result = try bigIntAmountFormatter.bigUInt(string: input, targetFractionalDigits: targetFractionalDigits)
      return result
    } catch {
      return (0, targetFractionalDigits)
    }
  }
}


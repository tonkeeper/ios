import Foundation
import BigInt
import TKCore
import KeeperCore

struct BuySellInputValidator {
  typealias Amount = (amount: BigUInt, fractionLength: Int)
  
  struct ValidationResult {
    let isValid: Bool
    let message: String?
  }
  
  private let minTonBuyAmount: BigUInt?
  private let minTonSellAmount: BigUInt?
  private let buyListController: BuyListController
  private let bigIntAmountFormatter: BigIntAmountFormatter
  
  init(
    minTonBuyAmount: BigUInt?,
    minTonSellAmount: BigUInt?,
    buyListController: BuyListController,
    bigIntAmountFormatter: BigIntAmountFormatter
  ) {
    self.minTonBuyAmount = minTonBuyAmount
    self.minTonSellAmount = minTonSellAmount
    self.buyListController = buyListController
    self.bigIntAmountFormatter = bigIntAmountFormatter
  }
  
  func validateBuy(amount: Amount) -> ValidationResult {
    let converted = convert(amount: amount)
    
    guard let minTonBuyAmount else {
      return ValidationResult(isValid: !converted.isZero, message: nil)
    }
    
    if converted >= minTonBuyAmount {
      return ValidationResult(isValid: true, message: nil)
    } else {
      let minAmount = bigIntAmountFormatter.format(amount: minTonBuyAmount, fractionDigits: TonInfo.fractionDigits, maximumFractionDigits: 2)
      return ValidationResult(isValid: false, message: "Min amount: \(minAmount)")
    }
  }
  
  func validateSell(amount: Amount) async -> ValidationResult {
    let converted = convert(amount: amount)
    let minSellValidation = validateMinSell(amount: converted)
    
    guard minSellValidation.isValid else {
      return minSellValidation
    }
    
    let isBalanceValid = await buyListController.isAmountAvailableToSend(amount: converted, token: .ton)
    if isBalanceValid {
      return ValidationResult(isValid: true, message: nil)
    } else {
      return ValidationResult(isValid: false, message: "Insufficient balance")
    }
  }
  
  private func validateMinSell(amount: BigUInt) -> ValidationResult {
    if let minTonSellAmount {
      if amount >= minTonSellAmount {
        return ValidationResult(isValid: true, message: nil)
      } else {
        let minAmount = bigIntAmountFormatter.format(amount: minTonSellAmount, fractionDigits: TonInfo.fractionDigits, maximumFractionDigits: 2)
        return ValidationResult(isValid: false, message: "Min amount: \(minAmount)")
      }
    } else {
      return ValidationResult(isValid: !amount.isZero, message: nil)
    }
  }
  
  private func convert(amount: Amount) -> BigUInt {
    if amount.fractionLength == TonInfo.fractionDigits {
      return amount.amount
    }
    
    return amount.0.short(to: amount.1 - TonInfo.fractionDigits)
  }
}

private extension BigUInt {
  func short(to count: Int) -> BigUInt {
    let divider = BigUInt(stringLiteral: "1" + String(repeating: "0", count: count))
    let newValue = self / divider
    return newValue
  }
}

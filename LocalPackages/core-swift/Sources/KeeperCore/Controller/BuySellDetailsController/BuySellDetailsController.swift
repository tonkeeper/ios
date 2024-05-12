import Foundation
import BigInt

public final class BuySellDetailsController {
  
  public struct Input {
    public enum Amount {
      case ton(BigUInt)
      case fiat(BigUInt)
    }
    
    var amount: Amount
    var fractionLength: Int
    
    public init(amount: Amount, fractionLength: Int) {
      self.amount = amount
      self.fractionLength = fractionLength
    }
  }
  
  private let rateConverter = RateConverter()
  
  private let ratesService: RatesService
  private let tonRatesLoader: TonRatesLoader
  private let tonRatesStore: TonRatesStore
  private let amountFormatter: AmountFormatter
  
  init(ratesService: RatesService, tonRatesLoader: TonRatesLoader, tonRatesStore: TonRatesStore, amountFormatter: AmountFormatter) {
    self.ratesService = ratesService
    self.tonRatesLoader = tonRatesLoader
    self.tonRatesStore = tonRatesStore
    self.amountFormatter = amountFormatter
  }
  
  public func start() async {
    
  }
  
  public func loadRate(for currency: Currency) async {
    await tonRatesLoader.loadRate(currency: currency)
  }
  
  public func convertAmountInput(_ input: Input, currency: Currency, outputFractionLenght: Int) async -> String {
    guard let rate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency }) else { return "" }
    
    let amount: BigUInt
    let correctedRate: Rates.Rate
    
    switch input.amount {
    case .ton(let value):
      amount = value
      correctedRate = rate
    case .fiat(let value):
      amount = value
      guard rate.rate > 0 else {
        correctedRate = rate
        break
      }
      correctedRate = Rates.Rate(
        currency: rate.currency,
        rate: 1 / rate.rate,
        diff24h: rate.diff24h
      )
    }
    
    let converted = rateConverter.convert(amount: amount, amountFractionLength: input.fractionLength, rate: correctedRate)
    return amountFormatter.formatAmount(
      converted.amount,
      fractionDigits: converted.fractionLength,
      maximumFractionDigits: outputFractionLenght
    )
  }
  
  public func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (value: BigUInt, fractionalDigits: Int) {
    guard !input.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = input.components(separatedBy: fractionalSeparator)
    guard components.count < 3 else {
      return (0, targetFractionalDigits)
    }
    
    var fractionalDigits = 0
    if components.count == 2 {
        let fractionalString = components[1]
        fractionalDigits = fractionalString.count
    }
    let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
    let bigIntValue = BigUInt(stringLiteral: components.joined() + zeroString)
    return (bigIntValue, targetFractionalDigits)
  }
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}

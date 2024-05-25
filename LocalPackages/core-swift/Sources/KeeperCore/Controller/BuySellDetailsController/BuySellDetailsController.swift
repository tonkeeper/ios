import Foundation
import BigInt

public final class BuySellDetailsController {
  public var didUpdateRates: (() -> Void)?
  
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
  
  private let ratesService: RatesService
  private let tonRatesLoader: TonRatesLoader
  private let tonRatesStore: TonRatesStore
  private let walletsStore: WalletsStore
  private let configurationStore: ConfigurationStore
  private let amountNewFormatter: AmountNewFormatter
  
  init(ratesService: RatesService,
       tonRatesLoader: TonRatesLoader,
       tonRatesStore: TonRatesStore,
       walletsStore: WalletsStore,
       configurationStore: ConfigurationStore,
       amountNewFormatter: AmountNewFormatter) {
    self.ratesService = ratesService
    self.tonRatesLoader = tonRatesLoader
    self.tonRatesStore = tonRatesStore
    self.walletsStore = walletsStore
    self.configurationStore = configurationStore
    self.amountNewFormatter = amountNewFormatter
  }
  
  public func start() async {
    _ = await tonRatesStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateRates:
        observer.didUpdateRates?()
      }
    }
  }
  
  public func loadRate(for currency: Currency) async {
    await tonRatesLoader.loadRate(currency: currency)
  }
  
  public func convertAmountInput(input: Input, providerRate: Decimal, currency: Currency, outputFractionLenght: Int) async -> String {
    let rate: Rates.Rate
    if providerRate.isZero {
      let tonRate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency })
      rate = tonRate ?? Rates.Rate(currency: currency, rate: 0, diff24h: nil)
    } else {
      rate = Rates.Rate(currency: currency, rate: providerRate, diff24h: nil)
    }
    
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
    
    let converted = RateConverter().convert(amount: amount, amountFractionLength: input.fractionLength, rate: correctedRate)
    return amountNewFormatter.formatAmount(
      converted.amount,
      fractionDigits: converted.fractionLength,
      maximumFractionDigits: outputFractionLenght
    )
  }
  
  public func convertAmountToString(amount: BigUInt,
                                    fractionDigits: Int,
                                    maximumFractionDigits: Int? = nil) -> String {
    let newMaximumFractionDigits = maximumFractionDigits ?? fractionDigits
    return amountNewFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: newMaximumFractionDigits,
      currency: nil
    )
  }
  
  public func convertStringToAmount(string: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    return amountNewFormatter.amount(from: string, targetFractionalDigits: targetFractionalDigits)
  }
  
  public func createActionUrl(actionTemplateURL: String?,
                              operatorId: String,
                              currencyFrom: Currency,
                              currencyTo: Currency) async -> URL? {
    guard let actionTemplateURL,
          let walletAddress = try? walletsStore.activeWallet.address.toString(bounceable: false)
    else {
      return nil
    }
    
    let currencyFromCode = currencyFrom.code
    let currencyToCode = currencyTo.code
    
    var urlString = actionTemplateURL
      .replacingOccurrences(of: "{ADDRESS}", with: walletAddress)
      .replacingOccurrences(of: "{CUR_FROM}", with: currencyFromCode)
      .replacingOccurrences(of: "{CUR_TO}", with: currencyToCode)
    
    if ["mercuryo", "mercuryo_sell"].contains(operatorId) {
      let txId = "mercuryo_" + UUID().uuidString
      urlString = urlString
        .replacingOccurrences(of: "{TX_ID}", with: txId)
      
      let mercuryoSecret = (try? await configurationStore.getConfiguration().mercuryoSecret) ?? ""

      if let signature = (walletAddress + mercuryoSecret).data(using: .utf8)?.sha256().hexString() {
        urlString += "&signature=\(signature)"
      }
    }
    
    return URL(string: urlString)
  }
}

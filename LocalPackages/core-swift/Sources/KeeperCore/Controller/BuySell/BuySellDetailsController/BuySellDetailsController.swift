import Foundation
import BigInt

public final class BuySellDetailsController {
  
  public var didUpdateRates: (() -> Void)?
  
  private let ratesService: RatesService
  private let tonRatesLoader: TonRatesLoader
  private let tonRatesStore: TonRatesStore
  private let walletsStore: WalletsStore
  private let configurationStore: ConfigurationStore
  private let amountNewFormatter: AmountNewFormatter
  private let decimalAmountFormatter: DecimalAmountFormatter
  
  init(ratesService: RatesService,
       tonRatesLoader: TonRatesLoader,
       tonRatesStore: TonRatesStore,
       walletsStore: WalletsStore,
       configurationStore: ConfigurationStore,
       amountNewFormatter: AmountNewFormatter,
       decimalAmountFormatter: DecimalAmountFormatter) {
    self.ratesService = ratesService
    self.tonRatesLoader = tonRatesLoader
    self.tonRatesStore = tonRatesStore
    self.walletsStore = walletsStore
    self.configurationStore = configurationStore
    self.amountNewFormatter = amountNewFormatter
    self.decimalAmountFormatter = decimalAmountFormatter
  }
  
  public func start() async {
    _ = await tonRatesStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateRates:
        Task { @MainActor in observer.didUpdateRates?() } 
      }
    }
  }
  
  public func loadRate(for currency: Currency) async {
    await tonRatesLoader.loadRate(currency: currency)
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
    return amountNewFormatter.amount(
      from: string,
      targetFractionalDigits: targetFractionalDigits
    )
  }
  
  public func getConvertedRate(token: BuySellItem.Token, currency: Currency, providerRate: Decimal? = nil) async -> String {
    if let providerRate {
      return decimalAmountFormatter.format(amount: providerRate)
    } else {
      return await convertTokenToFiat(token, currency: currency).amountString
    }
  }
  
  public func convertTokenToFiat(_ token: BuySellItem.Token, currency: Currency, providerRate: Decimal? = nil) async -> BuySellItem.Fiat {
    let rate: Rates.Rate
    if let providerRate {
      rate = Rates.Rate(currency: currency, rate: providerRate, diff24h: nil)
    } else {
      rate = await getRate(currency: currency)
    }
    
    let converted = convertAmount(
      amount: token.amount,
      usingRate: rate,
      amountFractionLength: token.fractionDigits,
      targetFractionLenght: 2
    )
    
    return BuySellItem.Fiat(
      amount: converted.amount,
      amountString: converted.string,
      currency: currency
    )
  }
  
  public func convertFiatToToken(_ fiat: BuySellItem.Fiat, token: BuySellModel.Token, providerRate: Decimal?) async -> BuySellItem.Token {
    let currency = fiat.currency
    var rate: Rates.Rate
    if let providerRate {
      rate = Rates.Rate(currency: currency, rate: providerRate, diff24h: nil)
    } else {
      rate = await getRate(currency: currency)
    }
    
    if !rate.rate.isZero {
      rate = Rates.Rate(
        currency: rate.currency,
        rate: 1 / rate.rate,
        diff24h: rate.diff24h
      )
    }
    
    let converted = convertAmount(
      amount: fiat.amount,
      usingRate: rate,
      amountFractionLength: 2,
      targetFractionLenght: token.fractionDigits
    )
    
    return BuySellItem.Token(
      amount: converted.amount,
      amountString: converted.string,
      token: token
    )
  }
  
  public func createActionUrl(actionTemplateURL: String?,
                              operatorId: String,
                              currencyFrom currencyFromCode: String,
                              currencyTo currencyToCode: String) async -> URL? {
    guard let actionTemplateURL else { return nil }
    guard let walletAddress = try? walletsStore.activeWallet.address.toString(bounceable: false) else { return nil }
    
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

private extension BuySellDetailsController {
  func convertAmount(amount: BigUInt,
                     usingRate rate: Rates.Rate,
                     amountFractionLength: Int,
                     targetFractionLenght: Int) -> (amount: BigUInt, string: String) {
    let converted = RateConverter().convert(
      amount: amount,
      amountFractionLength: amountFractionLength,
      rate: rate
    )
    let convertedAmount = truncateAmountFractionLenght(
      amount: converted.amount,
      currentLenght: converted.fractionLength,
      targetLenght: targetFractionLenght
    )
    let convertedString = amountNewFormatter.formatAmount(
      convertedAmount,
      fractionDigits: targetFractionLenght,
      maximumFractionDigits: targetFractionLenght
    )
    return (convertedAmount, convertedString)
  }
  
  func truncateAmountFractionLenght(amount: BigUInt, currentLenght: Int, targetLenght: Int) -> BigUInt {
    guard currentLenght > targetLenght else { return amount }
    let digitsToRemove = currentLenght - targetLenght
    let divisor = BigUInt(10).power(digitsToRemove)
    return amount / divisor
  }
  
  func getRate(currency: Currency) async -> Rates.Rate {
    let tonRate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency })
    return tonRate ?? Rates.Rate(currency: currency, rate: 0, diff24h: nil)
  }
}

import Foundation
import BigInt

public final class BuySellController {
  public var didUpdateMethods: (([[BuySellItemModel]]) -> Void)?
  
  private let wallet: Wallet
  private let buySellMethodsService: BuySellMethodsService
  private let locationService: LocationService
  private let configurationStore: ConfigurationStore
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let amountFormatter: AmountFormatter
  private let isMarketRegionPickerAvailable: () async -> Bool
  
  init(wallet: Wallet,
       buySellMethodsService: BuySellMethodsService,
       locationService: LocationService,
       configurationStore: ConfigurationStore,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       amountFormatter: AmountFormatter,
       isMarketRegionPickerAvailable: @escaping () async -> Bool) {
    self.wallet = wallet
    self.buySellMethodsService = buySellMethodsService
    self.locationService = locationService
    self.configurationStore = configurationStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
    self.isMarketRegionPickerAvailable = isMarketRegionPickerAvailable
  }
  
  public func start() async {
    if let cachedMethods = try? buySellMethodsService.getFiatMethods() {
      let models = await mapFiatMethods(cachedMethods)
      didUpdateMethods?(models)
    }
    
    do {
      let models = try await loadFiatMethods()
      didUpdateMethods?(models)
    } catch {
      didUpdateMethods?([])
    }
  }
  
  public func getActiveCurrency() async -> Currency {
    return await currencyStore.getActiveCurrency()
  }
  
  public func convertTokenAmountToCurrency(token: Token, _ amount: BigUInt, currency: Currency) async -> String {
    guard !amount.isZero else { return "0" }
    switch token {
    case .ton:
      guard let rate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency }) else { return "" }
      let converted = RateConverter().convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
      let formatted = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2
      )
      return formatted
    case .jetton:
//      let wallet = walletsStore.activeWallet
//      do {
//        let balance = try await walletBalanceStore.getBalanceState(walletAddress: try wallet.address)
//        guard let jettonBalance = balance.walletBalance.balance.jettonsBalance.first(where: {
//          $0.item.jettonInfo == jettonItem.jettonInfo
//        }) else { return "" }
//
//        guard let rate = jettonBalance.rates[currency] else { return ""}
//        let converted = RateConverter().convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
//        let formatted = amountFormatter.formatAmount(
//          converted.amount,
//          fractionDigits: converted.fractionLength,
//          maximumFractionDigits: 2,
//          currency: currency
//        )
//        return "≈ \(formatted)"
//      } catch {
//        return ""
//      }
      return ""
    }
  }
  
  public func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
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

private extension BuySellController {
  func loadFiatMethods() async throws -> [[BuySellItemModel]] {
    if await !isMarketRegionPickerAvailable() {
      return try await loadFiatMethodsByLocationRequired()
    } else {
      return try await loadDefaultFiatMethods()
    }
  }
  
  func loadFiatMethodsByLocationRequired() async throws -> [[BuySellItemModel]]  {
    do {
      let countryCode = try await locationService.getCountryCodeByIp()
      let methods = try await buySellMethodsService.loadFiatMethods(countryCode: countryCode)
      try? buySellMethodsService.saveFiatMethods(methods)
      return await mapFiatMethods(methods)
    } catch {
      return []
    }
  }
  
  func loadDefaultFiatMethods() async throws -> [[BuySellItemModel]]  {
    let methods = try await buySellMethodsService.loadFiatMethods(countryCode: nil)
    try? buySellMethodsService.saveFiatMethods(methods)
    return await mapFiatMethods(methods)
  }
  
  func mapFiatMethods(_ fiatMethods: FiatMethods) async -> [[BuySellItemModel]] {
    let currency = await currencyStore.getActiveCurrency()
    var sections = [[BuySellItemModel]]()
    for category in fiatMethods.categories {
      var items = [BuySellItemModel]()
      for categoryItem in category.items {
        guard availableFiatMethods.contains(categoryItem.id) else {
          continue
        }
        let item = BuySellItemModel(
          id: categoryItem.id,
          title: categoryItem.title,
          description: categoryItem.description,
          token: categoryItem.badge,
          iconURL: categoryItem.iconURL,
          actionButton: .init(title: categoryItem.actionButton.title, url: categoryItem.actionButton.url),
          infoButtons: categoryItem.infoButtons.map { .init(title: $0.title, url: $0.url) },
          actionURL: await actionUrl(for: categoryItem, currency: currency)
        )
        items.append(item)
      }
      sections.append(items)
    }
    return sections
  }
  
  func actionUrl(for item: FiatMethodItem, currency: Currency) async -> URL? {
  
    guard let address = try? wallet.address.toString(bounceable: false) else { return nil }
    var urlString = item.actionButton.url
    
    let currTo: String
    switch item.id {
    case "neocrypto", "moonpay":
      currTo = "TON"
    case "mercuryo":
      await handleUrlForMercuryo(urlString: &urlString, walletAddress: address)
      currTo = "TONCOIN"
    default:
      return nil
    }
    
    urlString = urlString.replacingOccurrences(of: "{CUR_FROM}", with: currency.code)
    urlString = urlString.replacingOccurrences(of: "{CUR_TO}", with: currTo)
    urlString = urlString.replacingOccurrences(of: "{ADDRESS}", with: address)
    
    guard let url = URL(string: urlString) else { return nil }
    return url
  }
  
  func handleUrlForMercuryo(urlString: inout String,
                            walletAddress: String) async {
    urlString = urlString.replacingOccurrences(of: "{TX_ID}", with: "mercuryo_\(UUID().uuidString)")
    
    let mercuryoSecret = (try? await configurationStore.getConfiguration().mercuryoSecret) ?? ""

    guard let signature = (walletAddress + mercuryoSecret).data(using: .utf8)?.sha256().hexString() else { return }
    urlString += "&signature=\(signature)"
  }
  
  private var availableFiatMethods: [FiatMethodItem.ID] {
      ["dreamwalkers", "dreamwalkers_sell", "mercuryo", "neocrypto", "moonpay"]
  }
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}

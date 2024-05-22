import Foundation
import BigInt

public final class BuyListController {
  public var didUpdateMethods: (([[BuySellItemModel]]) -> Void)?
  
  private let wallet: Wallet
  private let buySellMethodsService: BuySellMethodsService
  private let locationService: LocationService
  private let configurationStore: ConfigurationStore
  private let currencyStore: CurrencyStore
  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let tonRatesStore: TonRatesStore
  private let bigIntAmountFormatter: BigIntAmountFormatter
  private let isMarketRegionPickerAvailable: () async -> Bool
  
  init(wallet: Wallet,
       buySellMethodsService: BuySellMethodsService,
       locationService: LocationService,
       configurationStore: ConfigurationStore,
       currencyStore: CurrencyStore,
       walletsStore: WalletsStore,
       walletBalanceStore: WalletBalanceStore,
       tonRatesStore: TonRatesStore,
       bigIntAmountFormatter: BigIntAmountFormatter,
       isMarketRegionPickerAvailable: @escaping () async -> Bool) {
    self.wallet = wallet
    self.buySellMethodsService = buySellMethodsService
    self.locationService = locationService
    self.configurationStore = configurationStore
    self.currencyStore = currencyStore
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.tonRatesStore = tonRatesStore
    self.bigIntAmountFormatter = bigIntAmountFormatter
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
  
  public func fetchOperators(mode: TransactionMode, currency: Currency) async -> [Operator] {
    do {
      let models = try await loadOperators(mode: mode, currency: currency)
      return models
    } catch {
      return []
    }
  }
  
  public func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    do {
      let result = try bigIntAmountFormatter.bigUInt(string: input, targetFractionalDigits: targetFractionalDigits)
      return result
    } catch {
      return (0, targetFractionalDigits)
    }
  }
  
  public func isAmountAvailableToSend(amount: BigUInt, token: Token) async -> Bool {
    let wallet = walletsStore.activeWallet
    do {
      let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
      switch token {
      case .ton:
        return BigUInt(balance.walletBalance.balance.tonBalance.amount) >= amount
      case .jetton(let jettonItem):
        let jettonBalanceAmount = balance.walletBalance.balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
        return jettonBalanceAmount >= amount
      }
    } catch {
      return false
    }
  }
  
  public func convertTokenAmountToCurrency(_ amount: BigUInt) async -> String {
    let currency = await currencyStore.getActiveCurrency()
    guard !amount.isZero else { return "0.00 \(currency.rawValue)" }
    guard let rate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency }) else { return ""}
    let converted = RateConverter().convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
    let formatted = bigIntAmountFormatter.format(
      amount: converted.amount,
      fractionDigits: converted.fractionLength,
      maximumFractionDigits: 2
    )
    return "\(formatted)\(String.Symbol.shortSpace)\(currency.rawValue)"
  }
}

private extension BuyListController {
  func loadFiatMethods() async throws -> [[BuySellItemModel]] {
    if await !isMarketRegionPickerAvailable() {
      return try await loadFiatMethodsByLocationRequired()
    } else {
      return try await loadDefaultFiatMethods()
    }
  }
  
  func loadOperators(mode: TransactionMode, currency: Currency) async throws -> [Operator] {
    do {
      let operators = try await buySellMethodsService.loadOperators(mode: mode, currency: currency)
      return operators
    } catch {
      return []
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
      ["mercuryo", "neocrypto", "moonpay"]
  }
}

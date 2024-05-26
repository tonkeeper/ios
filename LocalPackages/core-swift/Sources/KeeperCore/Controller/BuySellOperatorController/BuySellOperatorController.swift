import Foundation
import BigInt

public final class BuySellOperatorController {
  
  public var didUpdateFiatOperatorItems: (([FiatOperator]) -> Void)?
  public var didUpdateActiveCurrency: ((Currency) -> Void)?
  public var didLoadListItems: ((Currency, [FiatOperator]) -> Void)?
  
  private let fiatOperatorCategory: FiatOperatorCategory
  private let buySellMethodsService: BuySellMethodsService
  private let locationService: LocationService
  private let tonRatesLoader: TonRatesLoader
  private let currencyStore: CurrencyStore
  private let walletsStore: WalletsStore
  private let configurationStore: ConfigurationStore
  private let decimalAmountFormatter: DecimalAmountFormatter
  
  init(fiatOperatorCategory: FiatOperatorCategory,
       buySellMethodsService: BuySellMethodsService,
       locationService: LocationService,
       tonRatesLoader: TonRatesLoader,
       currencyStore: CurrencyStore,
       walletsStore: WalletsStore,
       configurationStore: ConfigurationStore,
       decimalAmountFormatter: DecimalAmountFormatter) {
    self.fiatOperatorCategory = fiatOperatorCategory
    self.buySellMethodsService = buySellMethodsService
    self.locationService = locationService
    self.tonRatesLoader = tonRatesLoader
    self.currencyStore = currencyStore
    self.walletsStore = walletsStore
    self.configurationStore = configurationStore
    self.decimalAmountFormatter = decimalAmountFormatter
  }
  
  public func start() async {
    let activeCurrency = await currencyStore.getActiveCurrency()
    let fiatOperatorItems = await getFiatOperatorItems(activeCurrency: activeCurrency)
    await MainActor.run {
      didLoadListItems?(activeCurrency, fiatOperatorItems)
    }
  }
  
  public func updateFiatOperatorItems(forCurrency currency: Currency) async {
    let fiatOperatorItems = await getFiatOperatorItems(activeCurrency: currency)
    await MainActor.run {
      didUpdateFiatOperatorItems?(fiatOperatorItems)
    }
  }
  
  public func loadRate(for currency: Currency) async {
    await tonRatesLoader.loadRate(currency: currency)
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

private extension BuySellOperatorController {
  func getFiatOperatorItems(activeCurrency: Currency) async -> [FiatOperator] {
    let fiatMethodsCategories = await loadFiatMethodsCategories()
    let fiatRates = await loadFiatRates(category: fiatOperatorCategory.fiatMethodCategory, currency: activeCurrency)
    
    let items = fiatMethodsCategories
      .filter { $0.type == fiatOperatorCategory.fiatMethodCategory }
      .map { $0.items }
      .flatMap { $0 }
    
    let fiatRatesDict = Dictionary(uniqueKeysWithValues: fiatRates.map({ ($0.id, $0) }))
    
    var fiatOperatorItems = items
      .map { item in
        let fixedId = item.id.replacingOccurrences(of: "_sell", with: "")
        return mapFiatMethodItem(
          fiatMethodItem: item,
          fiatMethodRate: fiatRatesDict[fixedId],
          currency: activeCurrency
        )
      }
      .sorted(forCategory: fiatOperatorCategory)
    
    if !fiatOperatorItems.isEmpty && fiatOperatorItems[0].rate > 0 {
      fiatOperatorItems[0].badge = "BEST"
    }
    
    return fiatOperatorItems
  }
  
  func loadFiatMethodsCategories() async -> [FiatMethodCategory] {
    let fiatMethods = try? await buySellMethodsService.loadFiatMethods(countryCode: nil)
    return fiatMethods?.categories ?? []
  }
  
  func loadFiatRates(category: FiatMethodCategory.CategoryType, currency: Currency) async -> [FiatMethodRate] {
    let fiatRates = try? await buySellMethodsService.loadFiatRates(category: category, currency: currency)
    return fiatRates ?? []
  }
  
  func mapFiatMethodItem(fiatMethodItem: FiatMethodItem,
                         fiatMethodRate: FiatMethodRate?,
                         currency: Currency) -> FiatOperator {
    let rate = fiatMethodRate?.rate ?? .zero
    return FiatOperator(
      id: fiatMethodItem.id,
      title: fiatMethodItem.title,
      description: fiatMethodItem.description ?? "",
      badge: fiatMethodItem.badge,
      iconURL: fiatMethodItem.iconURL,
      actionTemplateURL: fiatMethodItem.actionButton.url,
      infoButtons: fiatMethodItem.infoButtons.map { mapInfoButton($0) },
      rate: rate,
      formattedRate: createFiatOperatorRate(
        rate: rate,
        currency: currency
      ),
      minTonBuyAmount: mapMinAmount(fiatMethodRate?.minTonBuyAmount),
      minTonSellAmount: mapMinAmount(fiatMethodRate?.minTonSellAmount)
    )
  }
  
  func createFiatOperatorRate(rate: Decimal, currency: Currency) -> String {
    guard !rate.isZero else { return " " }
    let formattedRate = decimalAmountFormatter.format(amount: rate)
    return "\(formattedRate) \(currency.code) for 1 TON"
  }
  
  func mapInfoButton(_ button: FiatMethodItem.ActionButton) -> FiatOperator.InfoButton {
    FiatOperator.InfoButton(title: button.title, url: URL(string: button.url))
  }
  
  func mapMinAmount(_ minAmount: UInt64?) -> BigUInt? {
    guard let minAmount else { return nil }
    return BigUInt(minAmount)
  }
}

public extension FiatOperator {
  func canOpenDetailsView() -> Bool {
    guard let actionTemplateURL else { return false }
    // i don't know what logic should be for selection between
    // provider webView/details view
    if actionTemplateURL.contains("{CUR_FROM}") {
      return true
    } else {
      return false
    }
  }
}

private extension Array where Element == FiatOperator {
  func sorted(forCategory category: FiatOperatorCategory) -> Self {
    return self.sorted { lhs, rhs in
      guard lhs.rate > 0 else { return false }
      guard rhs.rate > 0 else { return true }
      switch category {
      case .buy:
        return lhs.rate < rhs.rate
      case .sell:
        return lhs.rate > rhs.rate
      }
    }
  }
}

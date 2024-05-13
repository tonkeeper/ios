import Foundation

public final class BuySellOperatorController {
  public var didUpdateFiatOperatorItems: (([FiatOperator]) -> Void)?
  public var didUpdateActiveCurrency: ((Currency) -> Void)?
  public var didLoadListItems: ((Currency, [FiatOperator]) -> Void)?
  
  private let buySellMethodsService: BuySellMethodsService
  private let locationService: LocationService
  private let tonRatesLoader: TonRatesLoader
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  
  init(buySellMethodsService: BuySellMethodsService,
       locationService: LocationService,
       tonRatesLoader: TonRatesLoader,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore) {
    self.buySellMethodsService = buySellMethodsService
    self.locationService = locationService
    self.tonRatesLoader = tonRatesLoader
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
  }
  
  public func start(buySellOperationType: BuySellOperationType) async {
    let activeCurrency = await currencyStore.getActiveCurrency()
    let fiatMethods = try? await buySellMethodsService.loadFiatMethods(countryCode: nil)
    let fiatCategories = fiatMethods?.categories ?? []
    
    let fiatCategoryType = buySellOperationType.fiatCategoryType
    
    let buyItems = fiatCategories
      .filter({ $0.type == fiatCategoryType })
      .map({ $0.items })
      .flatMap({ $0 })
    
    let fiatOperatorItems = buyItems.map { mapFiatMethodItem($0) }
    
    await MainActor.run {
      didLoadListItems?(activeCurrency, fiatOperatorItems)
    }
  }
  
  public func loadRate(for currency: Currency) async {
    await tonRatesLoader.loadRate(currency: currency)
  }
}

private extension BuySellOperatorController {
  func mapFiatMethodItem(_ item: FiatMethodItem) -> FiatOperator {
    FiatOperator(
      id: item.id,
      title: item.title,
      description: item.description ?? "",
      rate: "2,330.01 AMD for 1 TON", // TODO: Refactor
      badge: item.badge,
      iconURL: item.iconURL,
      actionTemplateURL: item.actionButton.url,
      infoButtons: item.infoButtons.map({ .init(title: $0.title, url: URL(string: $0.url))})
    )
  }
}

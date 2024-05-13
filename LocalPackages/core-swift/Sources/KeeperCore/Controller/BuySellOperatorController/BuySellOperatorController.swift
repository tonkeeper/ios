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
    
    let fiatOperatorItems = buyItems.map({ mapFiatMethodItem($0) })
    
    await MainActor.run {
      didLoadListItems?(activeCurrency, fiatOperatorItems)
    }
  }
  
  public func loadRate(for currency: Currency) async {
    await tonRatesLoader.loadRate(currency: currency)
  }
  
  // TODO: Refactor
  public func updateBuySellOperatorItems() async {
//    let testInfoButtons: [FiatOperator.InfoButton] = [
//      .init(title: "Privacy Policy", url: URL(string: "https://example.com")),
//      .init(title: "Terms of Use", url: URL(string: "https://example.com"))
//    ]
//
//    let testFiatOperators: [FiatOperator] = [
//      .init(id: "mercuryo", title: "Mercuryo", description: "Instantly buy with a credit card", rate: 2,330.01 AMD for 1 TON", badge: "BEST", iconURL: URL(string: "https://tonkeeper.com/assets/mercuryo-icon-new.png")!, actionTemplateURL: "", infoButtons: testInfoButtons),
//      .init(id: "dreamwalkers", title: "Dreamwalkers", description: "Instantly buy with a credit card", rate: "2,330.01 AMD for 1 TON", badge: nil, iconURL: URL(string: "https://tonkeeper.com/assets/dreamwalkers-icon.png")!, actionTemplateURL: "", infoButtons: testInfoButtons),
//      .init(id: "neocrypto", title: "Neocrypto", description: "Instantly buy with a credit card", rate: "2,330.01 AMD for 1 TON", badge: nil, iconURL: URL(string: "https://tonkeeper.com/assets/neocrypto-new.png")!, actionTemplateURL: "", infoButtons: testInfoButtons),
//      .init(id: "transak", title: "Transak", description: "Instantly buy with a credit card", rate: "2,330.01 AMD for 1 TON", badge: nil, iconURL: URL(string: "https://tonkeeper.com/assets/transak.png")!, actionTemplateURL: "", infoButtons: testInfoButtons),
//    ]
    
    guard let fiatMethods = try? await buySellMethodsService.loadFiatMethods(countryCode: nil) else { return }
    
    let buyItems = fiatMethods.categories
      .filter({ $0.type == .buy })
      .map({ $0.items })
      .flatMap({ $0 })
    
    let fiatOperatorItems = buyItems.map({ mapFiatMethodItem($0) })
    
    await MainActor.run {
      didUpdateFiatOperatorItems?(fiatOperatorItems)
    }
  }
}

private extension BuySellOperatorController {
  func mapFiatMethodItem(_ item: FiatMethodItem) -> FiatOperator {
    FiatOperator(
      id: item.id,
      title: item.title,
      description: item.description ?? "",
      rate: "2,330.01 AMD for 1 TON",
      badge: item.badge,
      iconURL: item.iconURL,
      actionTemplateURL: item.actionButton.url,
      infoButtons: item.infoButtons.map({ .init(title: $0.title, url: URL(string: $0.url))})
    )
  }
}

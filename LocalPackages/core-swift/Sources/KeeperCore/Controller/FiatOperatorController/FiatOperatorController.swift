import Foundation

public final class FiatOperatorController {
  public var didUpdateFiatOperatorModel: ((FiatOperatorItemsModel) -> Void)?
  
  private let buySellMethodsService: BuySellMethodsService
  private let locationService: LocationService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  
  init(buySellMethodsService: BuySellMethodsService,
       locationService: LocationService,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore) {
    self.buySellMethodsService = buySellMethodsService
    self.locationService = locationService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
  }
  
  public func start() async {
    let testItemsModel = FiatOperatorItemsModel(fiatOperatorItems: [
      .init(identifier: "mercuryo", iconURL: URL(string: "https://tonkeeper.com/assets/mercuryo-icon-new.png")!, title: "Mercuryo", description: "2,330.01 AMD for 1 TON", tagText: "BEST"),
      .init(identifier: "dreamwalkers", iconURL: URL(string: "https://tonkeeper.com/assets/dreamwalkers-icon.png")!, title: "Dreamwalkers", description: "2,470.01 AMD for 1 TON"),
      .init(identifier: "neocrypto", iconURL: URL(string: "https://tonkeeper.com/assets/neocrypto-new.png")!, title: "Neocrypto", description: "2,475.01 AMD for 1 TON"),
      .init(identifier: "transak", iconURL: URL(string: "https://tonkeeper.com/assets/transak.png")!, title: "Transak", description: "2,570.01 AMD for 1 TON")
    ])
    
    await MainActor.run {
      didUpdateFiatOperatorModel?(testItemsModel)
    }
  }
  
  // TODO: Refactor
  public func updateFiatOperatorItems() async {
    guard let fiatMethods = try? await buySellMethodsService.loadFiatMethods(countryCode: nil) else { return }
    
    let buyItems = fiatMethods.categories
      .filter({ $0.type == .buy })
      .map({ $0.items })
      .flatMap({ $0 })
    
    let fiatOperatorItems = buyItems.map({ mapFiatMethodItem($0) })
    let fiatOperatorItemsModel = FiatOperatorItemsModel(fiatOperatorItems: fiatOperatorItems)
    
    await MainActor.run {
      didUpdateFiatOperatorModel?(fiatOperatorItemsModel)
    }
  }
}

private extension FiatOperatorController {
  func mapFiatMethodItem(_ item: FiatMethodItem) -> FiatOperatorItemsModel.Item {
    return .init(
      identifier: item.id,
      iconURL: item.iconURL,
      title: item.title,
      description: item.description ?? "",
      tagText: item.badge
    )
  }
}

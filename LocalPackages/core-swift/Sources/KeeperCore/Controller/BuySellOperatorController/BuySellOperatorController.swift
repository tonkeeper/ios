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
  
  //  https://api.tonkeeper.com/sign/moonpay?currencyCode=ton&baseCurrencyCode={CUR_FROM}&walletAddress={ADDRESS}&lang=en
  //  https://buy.neocrypto.net?cur_from={CUR_FROM}&cur_to={CUR_TO}&address={ADDRESS}&fix_cur_to=true&show_address=false&partner=tonkeeper&lang=en
  //  https://exchange.mercuryo.io?widget_id=4a399137-6863-4c47-8bd5-41f327aa33c3&networks=NEWTON&type=buy&fix_currency=true&hide_address=true&lang=en&theme=tonkeeper&currency={CUR_TO}&fiat_currency={CUR_FROM}&address={ADDRESS}&merchant_transaction_id={TX_ID}&return_url=https%3A%2F%2Ftonkeeper.com%2Fmercuryo_success%3Ftx_id%3D{TX_ID}
  //  https://dreamwalkers.io/en/tonkeeper/?wallet={ADDRESS}
  //  https://onramp.money/main/buy/?appId=445945&coinCode=ton&walletAddress={ADDRESS}
  //  https://widget.changelly.com/?from=btc,ton,usdtrx,usdtbsc,usdt20,eth,bnb,xrp,sol,ada,trx&to=eth,ton,btc,usdtrx,usdtbsc,usdt20,trx,sol,ada,xrp,bnb&amount=0.1&address={ADDRESS}&fromDefault=usdtrx&toDefault=ton&merchant_id=FF8aM-Mf2AY1Kg66&payment_id=&v=3
  //  https://global.transak.com/?hideMenu=true&disableWalletAddressForm=true&cryptoCurrencyCode=ton&productsAvailed=BUY&walletAddress={ADDRESS}&apiKey=c822e2bf-d71c-4f31-9f99-cc153e5eda58
  
  // TODO: Refactor
//  public func updateBuySellOperatorItems() async {
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
//    
//    guard let fiatMethods = try? await buySellMethodsService.loadFiatMethods(countryCode: nil) else { return }
//    
//    let buyItems = fiatMethods.categories
//      .filter({ $0.type == .buy })
//      .map({ $0.items })
//      .flatMap({ $0 })
//    
//    let fiatOperatorItems = buyItems.map({ mapFiatMethodItem($0) })
//    
//    await MainActor.run {
//      didUpdateFiatOperatorItems?(fiatOperatorItems)
//    }
//  }
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

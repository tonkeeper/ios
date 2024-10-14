import Foundation
import StoreKit
import KeeperCore

final class BatteryRefillIAPModel: NSObject, SKProductsRequestDelegate {

  var eventHandler: ((Event) -> Void)?
  
  enum Event {
    case didUpdateItems(items: [BatteryIAPItem])
  }
  
  var items: [BatteryIAPItem] {
    getItems()
  }
  
  private enum State {
    case idle
    case loading
    case processing
    
    var isItemEnable: Bool {
      self == .idle
    }
    
    var isLoading: Bool {
      self == .loading
    }
  }
  
  private var products = [SKProduct]()
  private var state: State = .loading {
    didSet {
      didUpdateState()
    }
  }
  
  private var request: SKProductsRequest?
  
  private let wallet: Wallet
  private let balanceStore: BalanceStore
  private let configurationStore: ConfigurationStore
  private let tonRatesStore: TonRatesStore
  
  init(wallet: Wallet,
       balanceStore: BalanceStore,
       configurationStore: ConfigurationStore,
       tonRatesStore: TonRatesStore) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.configurationStore = configurationStore
    self.tonRatesStore = tonRatesStore
  }

  func loadProducts() {
    self.request?.cancel()
    self.request = nil
    
    let productIdentifiers: Set<String> = Set(BatteryIAPPack.allCases.map { $0.productIdentifier })
    let productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
    productRequest.delegate = self
    productRequest.start()
    
    self.request = productRequest
  }
  
  func startProcessing() {
    state = .processing
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self.state = .idle
    }
  }
  
  private func getItems() -> [BatteryIAPItem] {
    let batteryBalance = balanceStore.getState()[wallet]?.walletBalance.batteryBalance
    let configuration = self.configurationStore.getConfiguration()
    let tonPriceUSD: NSDecimalNumber? = {
      let rates = self.tonRatesStore.getState()
      guard let usdRates = rates.first(where: { $0.currency == .USD })?.rate else { return nil }
      return NSDecimalNumber(decimal: usdRates)
    }()
    
    let items: [BatteryIAPItem] = BatteryIAPPack.allCases.compactMap { pack -> BatteryIAPItem? in
      guard !state.isLoading else {
        return BatteryIAPItem(pack: pack, isEnable: state.isItemEnable, state: .loading)
      }
      
      guard let product = products.first(where: { $0.productIdentifier == pack.productIdentifier }),
            let currencyCode = product.priceLocale.currencyCode,
            let currency = Currency(code: currencyCode) else { return nil }
      
      let price = product.price.decimalValue
      let charges = calculateChargesCount(pack: pack,
                                          batteryBalance: batteryBalance,
                                          tonPriceUSD: tonPriceUSD,
                                          configuration: configuration)
      
      let amount = BatteryIAPItem.Amount(
        price: price,
        currency: currency,
        charges: charges
      )
      
      return BatteryIAPItem(pack: pack,
                            isEnable: state.isItemEnable,
                            state: BatteryIAPItem.State.amount(amount))
    }
    return items
  }
  
  private func didUpdateProducts() {
    eventHandler?(.didUpdateItems(items: getItems()))
  }
  
  private func didUpdateState() {
    eventHandler?(.didUpdateItems(items: getItems()))
  }

  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    guard request == self.request else { return }
    self.products = response.products
    self.state = .idle
    self.request = nil
  }
  
  private func calculateChargesCount(pack: BatteryIAPPack,
                                     batteryBalance: BatteryBalance?,
                                     tonPriceUSD: NSDecimalNumber?,
                                     configuration: RemoteConfiguration) -> Int {
    guard let batteryMeanFees = configuration.batteryMeanFeesDecimaNumber,
          let batteryReservedAmount = configuration.batteryReservedAmountDecimalNumber,
          let tonPriceUSD else { return 0 }
    let isBalanceEmpty = batteryBalance?.balanceDecimalNumber == 0 && batteryBalance?.reservedDecimalNumber == 0
    let reservedAmount: NSDecimalNumber = isBalanceEmpty ? batteryReservedAmount : 0
    
    return NSDecimalNumber(decimal: pack.userProceed)
      .dividing(by: tonPriceUSD, withBehavior: NSDecimalNumberHandler.dividingRoundBehaviour)
      .subtracting(reservedAmount)
      .dividing(by: batteryMeanFees, withBehavior: NSDecimalNumberHandler.dividingRoundBehaviour)
      .rounding(accordingToBehavior: NSDecimalNumberHandler.roundBehaviour)
      .intValue
  }
}

private extension NSDecimalNumberHandler {
  static var dividingRoundBehaviour: NSDecimalNumberHandler {
    return NSDecimalNumberHandler(
      roundingMode: .plain,
      scale: 20,
      raiseOnExactness: false,
      raiseOnOverflow: false,
      raiseOnUnderflow: false,
      raiseOnDivideByZero: false
    )
  }
  
  static var roundBehaviour: NSDecimalNumberHandler {
    return NSDecimalNumberHandler(
      roundingMode: .plain,
      scale: 0,
      raiseOnExactness: false,
      raiseOnOverflow: false,
      raiseOnUnderflow: false,
      raiseOnDivideByZero: false
    )
  }
}

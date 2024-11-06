import Foundation
import StoreKit
import KeeperCore

final class BatteryRefillIAPModel: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {

  var eventHandler: ((Event) -> Void)?
  
  enum Event {
    case didUpdateItems(items: [BatteryIAPItem])
    case didPerformTransaction
  }
  
  var items: [BatteryIAPItem] {
    getItems()
  }
  
  var promocode: String?
  
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
  private let batteryService: BatteryService
  private let tonProofService: TonProofTokenService
  private let balanceStore: BalanceStore
  private let configuration: Configuration
  private let tonRatesStore: TonRatesStore
  
  init(wallet: Wallet,
       batteryService: BatteryService,
       tonProofService: TonProofTokenService,
       balanceStore: BalanceStore,
       configuration: Configuration,
       tonRatesStore: TonRatesStore) {
    self.wallet = wallet
    self.batteryService = batteryService
    self.tonProofService = tonProofService
    self.balanceStore = balanceStore
    self.configuration = configuration
    self.tonRatesStore = tonRatesStore
    super.init()
    SKPaymentQueue.default().add(self)
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
  
  func startProcessing(identifier: String) {
    guard SKPaymentQueue.canMakePayments(),
    let product = products.first(where: { $0.productIdentifier == identifier }) else { return }
    let payment = SKPayment(product: product)
    SKPaymentQueue.default().add(payment)
  }
  
  func restorePurchases() {
    SKPaymentQueue.default().restoreCompletedTransactions()
  }
  
  private func getItems() -> [BatteryIAPItem] {
    let batteryBalance = balanceStore.getState()[wallet]?.walletBalance.batteryBalance
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
    DispatchQueue.main.async {
      guard request == self.request else { return }
      self.products = response.products
      self.state = .idle
      self.request = nil
    }
  }
  
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      switch transaction.transactionState {
      case .purchasing:
        state = .processing
      case .purchased:
        SKPaymentQueue.default().finishTransaction(transaction)
        makePurchase(transaction: transaction)
        state = .idle
      case .failed:
        SKPaymentQueue.default().finishTransaction(transaction)
        state = .idle
      case .restored:
        SKPaymentQueue.default().finishTransaction(transaction)
        makePurchase(transaction: transaction)
        state = .idle
      case .deferred:
        state = .idle
      @unknown default:
        break
      }
    }
  }
  
  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {}
  
  func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: any Error) {}

  
  private func makePurchase(transaction: SKPaymentTransaction) {
    guard let id = transaction.transactionIdentifier,
    let tonProof = try? tonProofService.getWalletToken(wallet)  else { return }
    Task { @MainActor in
      _ = try await batteryService.makePurchase(wallet: wallet, tonProofToken: tonProof, transactionId: id, promocode: promocode)
      eventHandler?(.didPerformTransaction)
    }
  }
  
  private func calculateChargesCount(pack: BatteryIAPPack,
                                     batteryBalance: BatteryBalance?,
                                     tonPriceUSD: NSDecimalNumber?,
                                     configuration: Configuration) -> Int {
    guard let batteryMeanFees = configuration.batteryMeanFeesDecimaNumber(isTestnet: wallet.isTestnet),
          let batteryReservedAmount = configuration.batteryReservedAmountDecimalNumber(isTestnet: wallet.isTestnet),
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

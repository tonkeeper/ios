import Foundation
import StoreKit
import KeeperCore

final class BatteryRefillIAPModel: NSObject {

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
  
  @Atomic
  private var restorePurchasesTask: Task<Result<Void, RestorePurchaseError>, Never>?
  @Atomic
  private var refreshReceiptContinuation: CheckedContinuation<Void, Swift.Error>?
  
  private let wallet: Wallet
  private let batteryService: BatteryService
  private let tonProofService: TonProofTokenService
  private let balanceStore: BalanceStore
  private let configuration: Configuration
  private let tonRatesStore: TonRatesStore
  private let balanceLoader: BalanceLoader
  
  init(wallet: Wallet,
       batteryService: BatteryService,
       tonProofService: TonProofTokenService,
       balanceStore: BalanceStore,
       configuration: Configuration,
       tonRatesStore: TonRatesStore,
       balanceLoader: BalanceLoader) {
    self.wallet = wallet
    self.batteryService = batteryService
    self.tonProofService = tonProofService
    self.balanceStore = balanceStore
    self.configuration = configuration
    self.tonRatesStore = tonRatesStore
    self.balanceLoader = balanceLoader
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
  
  func restorePurchases() async -> Result<Void, RestorePurchaseError>  {
    SKPaymentQueue.default().restoreCompletedTransactions()
    refreshReceiptContinuation = nil
    restorePurchasesTask?.cancel()
    let restorePurchasesTask = Task<Result<Void, RestorePurchaseError>, Never> { [weak self] in
      guard let self else { return .failure(.receiptRefreshFailed) }
      do {
        try await withCheckedThrowingContinuation { [weak self] continuation in
          self?.refreshReceiptContinuation = continuation
          let request = SKReceiptRefreshRequest()
          request.delegate = self
          request.start()
        }
        return await self.restoreProductsByReceipt()
      } catch {
        return .failure(.receiptRefreshFailed)
      }
    }
    self.restorePurchasesTask = restorePurchasesTask
    let result = await restorePurchasesTask.result
    return result.get()
  }
  
  private func getItems() -> [BatteryIAPItem] {
    let batteryBalance = balanceStore.getState()[wallet]?.walletBalance.batteryBalance
    let tonPriceUSD: NSDecimalNumber? = {
      let rates = self.tonRatesStore.getState()
      guard let usdRates = rates.tonRates.first(where: { $0.currency == .USD })?.rate else { return nil }
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

  private func makePurchase(transaction: SKPaymentTransaction,
                            completion: @escaping () -> Void) {
    guard let id = transaction.transactionIdentifier,
    let tonProof = try? tonProofService.getWalletToken(wallet)  else { return }
    Task { @MainActor in
      do {
        _ = try await batteryService.makePurchase(wallet: wallet, tonProofToken: tonProof, transactionId: id, promocode: promocode)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        balanceLoader.loadActiveWalletBalance()
        completion()
      } catch {
        completion()
      }
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
  
  private func restoreProductsByReceipt() async -> Result<Void, RestorePurchaseError> {
    guard let receiptURL = Bundle.main.appStoreReceiptURL,
    let receipt = try? Data(contentsOf: receiptURL) else {
      return .failure(.invalidReceipt)
    }
    
    let base64encodedReceipt = receipt.base64EncodedString()
    
    do {
      let productionPurchases = try await validateReceipt(
        receipt: base64encodedReceipt,
        validationType: .production
      ).get()

      return await handleValidatedReceipt(purchases: productionPurchases)
    } catch {
      do {
        let sandboxPurchases = try await validateReceipt(
          receipt: base64encodedReceipt,
          validationType: .sandbox
        ).get()
        return await handleValidatedReceipt(purchases: sandboxPurchases)
      } catch {
        return .failure(.validationFailed)
      }
    }
  }
  private func validateReceipt(receipt: String,
                               validationType: ReceiptValidationType) async -> Result<[ValidatedReceipt.InAppPurchase], RestorePurchaseError> {
    let requestDictionary = ["receipt-data": receipt]
    guard JSONSerialization.isValidJSONObject(requestDictionary) else {
      return .failure(.invalidReceipt)
    }
    do {
      let requestData = try JSONSerialization.data(withJSONObject: requestDictionary)
      let session = URLSession(configuration: .default)
      var request = URLRequest(url: validationType.url)
      request.httpMethod = "POST"
      request.cachePolicy = .reloadIgnoringCacheData
      
      let (data, response) = try await session.upload(for: request, from: requestData)
      guard let httpResponse = response as? HTTPURLResponse else {
        return .failure(.validationFailed)
      }
      guard (200..<300).contains(httpResponse.statusCode) else {
        return .failure(.validationFailed)
      }
      
      let validatedReceipt = try JSONDecoder().decode(ValidatedReceipt.self, from: data)
      switch validatedReceipt {
      case .success(let purchases):
        return .success(purchases)
      case .failed:
        return .failure(.validationFailed)
      }
    } catch {
      return .failure(.validationFailed)
    }
  }
  
  func handleValidatedReceipt(purchases: [ValidatedReceipt.InAppPurchase]) async -> Result<Void, RestorePurchaseError> {
    guard !purchases.isEmpty else { return .failure(.nothingToRestore)}
    guard let tonProof = try? tonProofService.getWalletToken(wallet) else {
      return .failure(.batteryPurchaseFailed)
    }
    for purchase in purchases {
      do {
        _ = try await batteryService.makePurchase(
          wallet: wallet,
          tonProofToken: tonProof,
          transactionId: purchase.originalTransactionId,
          promocode: promocode)
      } catch {
        return .failure(.batteryPurchaseFailed)
      }
    }
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    balanceLoader.loadActiveWalletBalance()
    return .success(())
  }
}

extension BatteryRefillIAPModel: SKProductsRequestDelegate {
  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    DispatchQueue.main.async {
      guard request == self.request else { return }
      self.products = response.products
      self.state = .idle
      self.request = nil
    }
  }
  
  func requestDidFinish(_ request: SKRequest) {
    if let _ = request as? SKReceiptRefreshRequest,
    let refreshReceiptContinuation {
      refreshReceiptContinuation.resume(returning: ())
    }
  }
  
  func request(_ request: SKRequest, didFailWithError error: any Error) {
    if let _ = request as? SKReceiptRefreshRequest,
    let refreshReceiptContinuation {
      refreshReceiptContinuation.resume(throwing: error)
    }
  }
}

extension BatteryRefillIAPModel: SKPaymentTransactionObserver {
  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      switch transaction.transactionState {
      case .purchasing:
        state = .processing
      case .purchased:
        SKPaymentQueue.default().finishTransaction(transaction)
        makePurchase(transaction: transaction) { [weak self] in
          self?.state = .idle
          self?.eventHandler?(.didPerformTransaction)
        }
      case .failed:
        SKPaymentQueue.default().finishTransaction(transaction)
        state = .idle
      case .restored:
        SKPaymentQueue.default().finishTransaction(transaction)
        makePurchase(transaction: transaction) { [weak self] in
          self?.state = .idle
          self?.eventHandler?(.didPerformTransaction)
        }
      case .deferred:
        state = .idle
      @unknown default:
        break
      }
    }
  }
  
  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {}
  
  func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: any Error) {}
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

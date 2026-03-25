import Foundation
import KeeperCore
import StoreKit
import TKLogging

final class BatteryRefillIAPModel: NSObject {
    var eventHandler: ((Event) -> Void)?
    private let logger = LogDomain.inAppPurchases

    enum Event {
        case didUpdateItems(items: [BatteryIAPItem])
        case didPerformTransaction
        case didFailTransaction(error: Error?)
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

    init(
        wallet: Wallet,
        batteryService: BatteryService,
        tonProofService: TonProofTokenService,
        balanceStore: BalanceStore,
        configuration: Configuration,
        tonRatesStore: TonRatesStore,
        balanceLoader: BalanceLoader
    ) {
        self.wallet = wallet
        self.batteryService = batteryService
        self.tonProofService = tonProofService
        self.balanceStore = balanceStore
        self.configuration = configuration
        self.tonRatesStore = tonRatesStore
        self.balanceLoader = balanceLoader
        super.init()
        SKPaymentQueue.default().add(self)
        logger.i("IAPModel initialized, testnet=\(self.wallet.network == .testnet)")
    }

    func loadProducts() {
        logger.i("Loading products for battery packs")
        self.request?.cancel()
        self.request = nil

        let productIdentifiers: Set<String> = Set(BatteryIAPPack.allCases.map { $0.productIdentifier })
        let productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productRequest.delegate = self
        productRequest.start()
        logger.i("Products request started: ids=\(productIdentifiers)")

        self.request = productRequest
    }

    func startProcessing(identifier: String) {
        logger.i("Start processing purchase for product id=\(identifier)")
        guard SKPaymentQueue.canMakePayments(),
              let product = products.first(where: { $0.productIdentifier == identifier }) else { return }
        logger.d("Found product in loaded list, proceeding to add payment")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
        logger.i("Payment added to queue for id=\(identifier)")
    }

    private func makePurchase(
        transaction: SKPaymentTransaction,
        completion: @escaping (_ success: Bool) -> Void
    ) {
        logger.i("Handling purchased/restored transaction id=\(transaction.transactionIdentifier ?? "nil")")
        guard let id = transaction.transactionIdentifier,
              let tonProof = try? tonProofService.getWalletToken(wallet)
        else {
            logger.e("Missing transaction id or tonProof; cannot make purchase")
            completion(false)
            return
        }
        Task { @MainActor in
            do {
                logger.i("Calling batteryService.makePurchase")
                let purchaseStatus = try await batteryService.makePurchase(wallet: wallet, tonProofToken: tonProof, transactionId: id, promocode: promocode)

                if let transactionResult = purchaseStatus.transactions.first(where: { $0.transaction_id == id }) {
                    if transactionResult.success {
                        logger.i("batteryService.makePurchase succeeded")
                        balanceLoader.loadActiveWalletBalance()
                        completion(true)
                    } else {
                        logger.w("Transaction confirmation failed. Msg: \(String(describing: transactionResult.error?.msg)), code: \(String(describing: transactionResult.error?.code.rawValue))")
                        completion(false)
                    }
                } else {
                    logger.w("Can't find info about passed transaction in response")
                    completion(false)
                }
            } catch {
                logger.e("batteryService.makePurchase failed: \(String(describing: error))")
                completion(false)
            }
        }
    }

    func restorePurchases() async -> Result<Void, RestorePurchaseError> {
        logger.i("Restore purchases started")
        SKPaymentQueue.default().restoreCompletedTransactions()
        logger.d("Requested restoreCompletedTransactions on payment queue")
        refreshReceiptContinuation = nil
        restorePurchasesTask?.cancel()
        let restorePurchasesTask = Task<Result<Void, RestorePurchaseError>, Never> { [weak self] in
            guard let self else { return .failure(.receiptRefreshFailed) }
            do {
                logger.d("Refreshing receipt via SKReceiptRefreshRequest")
                try await withCheckedThrowingContinuation { [weak self] continuation in
                    self?.refreshReceiptContinuation = continuation
                    let request = SKReceiptRefreshRequest()
                    request.delegate = self
                    request.start()
                }
                return await self.restoreProductsByReceipt()
            } catch {
                logger.e("Receipt refresh failed during restore: \(String(describing: error))")
                return .failure(.receiptRefreshFailed)
            }
        }
        self.restorePurchasesTask = restorePurchasesTask
        let result = await restorePurchasesTask.result
        logger.i("Restore purchases finished with result: \(String(describing: result.get()))")
        return result.get()
    }

    private func getItems() -> [BatteryIAPItem] {
        let batteryBalance = balanceStore.getState()[wallet]?.walletBalance.batteryBalance
        let tonPriceUSD: NSDecimalNumber? = {
            let rates = self.tonRatesStore.getState()
            guard let usdRates = rates.tonRates.first(where: { $0.currency == .USD })?.rate else { return nil }
            return NSDecimalNumber(decimal: usdRates)
        }()

        return BatteryIAPPack.allCases.compactMap { pack -> BatteryIAPItem? in
            guard !state.isLoading else {
                return BatteryIAPItem(pack: pack, isEnable: state.isItemEnable, state: .loading)
            }

            guard let product = products.first(where: { $0.productIdentifier == pack.productIdentifier }),
                  let currencyCode = product.priceLocale.currencyCode,
                  let currency = Currency(code: currencyCode) else { return nil }

            let price = product.price.decimalValue
            let charges = calculateChargesCount(
                pack: pack,
                batteryBalance: batteryBalance,
                tonPriceUSD: tonPriceUSD,
                configuration: configuration
            )

            let amount = BatteryIAPItem.Amount(
                price: price,
                currency: currency,
                charges: charges
            )

            return BatteryIAPItem(
                pack: pack,
                isEnable: state.isItemEnable,
                state: BatteryIAPItem.State.amount(amount)
            )
        }
    }

    private func didUpdateState() {
        logger.d("State updated: \(String(describing: self.state))")
        eventHandler?(.didUpdateItems(items: getItems()))
    }

    private func calculateChargesCount(
        pack: BatteryIAPPack,
        batteryBalance: BatteryBalance?,
        tonPriceUSD: NSDecimalNumber?,
        configuration: Configuration
    ) -> Int {
        guard let batteryMeanFees = configuration.batteryMeanFeesDecimaNumber(network: wallet.network),
              let batteryReservedAmount = configuration.batteryReservedAmountDecimalNumber(network: wallet.network),
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
        logger.i("Restoring products by receipt")
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receipt = try? Data(contentsOf: receiptURL)
        else {
            logger.e("Invalid or missing receipt URL/data")
            return .failure(.invalidReceipt)
        }

        let base64encodedReceipt = receipt.base64EncodedString()

        do {
            logger.d("Validating receipt against production server")
            let productionPurchases = try await validateReceipt(
                receipt: base64encodedReceipt,
                validationType: .production
            ).get()

            return await handleValidatedReceipt(purchases: productionPurchases)
        } catch {
            logger.w("Production validation failed, trying sandbox")
            do {
                let sandboxPurchases = try await validateReceipt(
                    receipt: base64encodedReceipt,
                    validationType: .sandbox
                ).get()
                return await handleValidatedReceipt(purchases: sandboxPurchases)
            } catch {
                logger.e("Sandbox validation failed too :((")
                return .failure(.validationFailed)
            }
        }
    }

    private func validateReceipt(
        receipt: String,
        validationType: ReceiptValidationType
    ) async -> Result<[ValidatedReceipt.InAppPurchase], RestorePurchaseError> {
        logger.d("validateReceipt called")
        let requestDictionary = ["receipt-data": receipt]
        guard JSONSerialization.isValidJSONObject(requestDictionary) else {
            logger.e("Receipt JSON invalid")
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
            logger.d("Receipt validation HTTP status=\(httpResponse.statusCode)")
            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                return .failure(.validationFailed)
            }

            let validatedReceipt = try JSONDecoder().decode(ValidatedReceipt.self, from: data)
            switch validatedReceipt {
            case let .success(purchases):
                logger.i("Receipt validated successfully with \(purchases.count) purchases")
                return .success(purchases)
            case .failed:
                logger.e("Receipt validation returned failed status")
                return .failure(.validationFailed)
            }
        } catch {
            logger.e("Receipt validation error: \(String(describing: error))")
            return .failure(.validationFailed)
        }
    }

    func handleValidatedReceipt(purchases: [ValidatedReceipt.InAppPurchase]) async -> Result<Void, RestorePurchaseError> {
        logger.i("Handling validated receipt with purchases count=\(purchases.count)")
        guard !purchases.isEmpty else {
            logger.i("Nothing to restore from receipt")
            return .failure(.nothingToRestore)
        }
        guard let tonProof = try? tonProofService.getWalletToken(wallet) else {
            logger.e("Failed to get tonProof token for restore")
            return .failure(.batteryPurchaseFailed)
        }
        for purchase in purchases {
            do {
                logger.i("Restoring purchase")
                _ = try await batteryService.makePurchase(
                    wallet: wallet,
                    tonProofToken: tonProof,
                    transactionId: purchase.originalTransactionId,
                    promocode: promocode
                )
            } catch {
                logger.e("batteryService.makePurchase failed during restore")
                return .failure(.batteryPurchaseFailed)
            }
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        balanceLoader.loadActiveWalletBalance()
        logger.i("Restore flow completed successfully")
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
            self.logger.i("Received products response: count=\(response.products.count)")
        }
    }

    func requestDidFinish(_ request: SKRequest) {
        if let _ = request as? SKReceiptRefreshRequest,
           let refreshReceiptContinuation
        {
            logger.i("Receipt refresh request finished successfully")
            refreshReceiptContinuation.resume(returning: ())
            self.refreshReceiptContinuation = nil
        }
    }

    func request(_ request: SKRequest, didFailWithError error: any Error) {
        if let _ = request as? SKReceiptRefreshRequest,
           let refreshReceiptContinuation
        {
            logger.e("Receipt refresh request failed: \(String(describing: error))")
            refreshReceiptContinuation.resume(throwing: error)
            self.refreshReceiptContinuation = nil
        }
    }
}

extension BatteryRefillIAPModel: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        logger.d("updatedTransactions received: count=\(transactions.count)")
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                logger.i("Transaction purchasing: \(transaction.payment.productIdentifier)")
                state = .processing
            case .purchased:
                logger.i("Transaction purchased")
                makePurchase(transaction: transaction) { [weak self] success in
                    if success {
                        SKPaymentQueue.default().finishTransaction(transaction)
                        self?.state = .idle
                        self?.eventHandler?(.didPerformTransaction)
                    } else {
                        self?.state = .idle
                        self?.eventHandler?(.didFailTransaction(error: nil))
                    }
                }
            case .failed:
                logger.e("Transaction failed")
                SKPaymentQueue.default().finishTransaction(transaction)
                state = .idle
                eventHandler?(.didFailTransaction(error: transaction.error))
            case .restored:
                logger.i("Transaction restored")
                makePurchase(transaction: transaction) { [weak self] success in
                    if success {
                        SKPaymentQueue.default().finishTransaction(transaction)
                        self?.state = .idle
                        self?.eventHandler?(.didPerformTransaction)
                    } else {
                        self?.state = .idle
                        self?.eventHandler?(.didFailTransaction(error: nil))
                    }
                }
            case .deferred:
                logger.i("Transaction deferred")
                state = .idle
            @unknown default:
                break
            }
        }
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        logger.i("Restore completed transactions finished")
    }

    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: any Error) {
        logger.e("Restore completed transactions failed: \(String(describing: error))")
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

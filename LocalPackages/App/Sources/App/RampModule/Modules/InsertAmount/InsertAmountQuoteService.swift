import Foundation
import KeeperCore

protocol InsertAmountQuoteServicing {
    var createsOrderOnContinue: Bool { get }

    func loadMerchants(providerIds: [String]) async throws -> [OnRampMerchantInfo]
    func fetchQuotes(
        flow: RampFlow,
        amount: String,
        currencyCode: String,
        paymentMethodType: String,
        merchantId: String?
    ) async throws -> InsertAmountQuotesState
    func resolveWidgetURL(
        flow: RampFlow,
        amount: String,
        currencyCode: String,
        paymentMethodType: String,
        merchantId: String,
        merchantTransactionId: String
    ) async throws -> URL
}

struct LegacyInsertAmountQuoteService: InsertAmountQuoteServicing {
    let wallet: Wallet
    let asset: RampAsset
    let onRampService: OnRampService

    var createsOrderOnContinue: Bool {
        false
    }

    func loadMerchants(providerIds: [String]) async throws -> [OnRampMerchantInfo] {
        let merchants = try await onRampService.getMerchants(walletId: wallet.multichainWalletId)
        return merchants.filter { providerIds.contains($0.id) }
    }

    func fetchQuotes(
        flow: RampFlow,
        amount: String,
        currencyCode: String,
        paymentMethodType: String,
        merchantId: String?
    ) async throws -> InsertAmountQuotesState {
        guard let walletAddress = wallet.legacyOnRampWalletAddress(isTronNetwork: asset.isTronNetwork) else {
            return InsertAmountQuotesState(quotes: [], suggestedQuotes: [])
        }

        let purchaseType: OnRampPurchaseType
        let from: String
        let to: String
        let fromNetwork: String?
        let toNetwork: String?

        switch flow {
        case .deposit:
            purchaseType = .buy
            from = currencyCode
            to = asset.symbol
            fromNetwork = nil
            toNetwork = asset.network
        case .withdraw:
            purchaseType = .sell
            from = asset.symbol
            to = currencyCode
            fromNetwork = asset.network
            toNetwork = nil
        }

        let result = try await onRampService.calculate(
            from: from,
            to: to,
            amount: amount,
            walletAddress: walletAddress,
            purchaseType: purchaseType,
            fromNetwork: fromNetwork,
            toNetwork: toNetwork,
            paymentMethodType: paymentMethodType,
            walletId: wallet.multichainWalletId
        )

        return InsertAmountQuotesState(
            quotes: result.quotes.map(mapLegacyQuote),
            suggestedQuotes: result.suggestedQuotes.map(mapLegacyQuote)
        )
    }

    func resolveWidgetURL(
        flow: RampFlow,
        amount: String,
        currencyCode: String,
        paymentMethodType: String,
        merchantId: String,
        merchantTransactionId: String
    ) async throws -> URL {
        let quotes = try await fetchQuotes(
            flow: flow,
            amount: amount,
            currencyCode: currencyCode,
            paymentMethodType: paymentMethodType,
            merchantId: merchantId
        )
        let quote = quotes.quotes.first(where: { $0.merchantId == merchantId })
            ?? quotes.suggestedQuotes.first(where: { $0.merchantId == merchantId })
        guard let widgetURL = quote?.widgetURL else {
            throw InsertAmountQuoteServiceError.missingWidgetURL
        }
        return widgetURL
    }

    private func mapLegacyQuote(_ quote: OnRampQuoteResult) -> InsertAmountMerchantQuote {
        InsertAmountMerchantQuote(
            merchantId: quote.merchantId,
            merchantTransactionId: quote.merchantTransactionId,
            convertedAmount: Decimal(quote.amount),
            amountIn: nil,
            rate: nil,
            minAmount: quote.minAmount,
            maxAmount: quote.maxAmount,
            widgetURL: quote.widgetUrl.flatMap(URL.init(string:))
        )
    }
}

struct MultichainInsertAmountQuoteService: InsertAmountQuoteServicing {
    let wallet: Wallet
    let assetDetail: OnRampAssetDetail
    let multichainRampService: MultichainRampService
    let onRampService: OnRampService

    var createsOrderOnContinue: Bool {
        true
    }

    func loadMerchants(providerIds: [String]) async throws -> [OnRampMerchantInfo] {
        let merchants = try await onRampService.getMerchants(walletId: wallet.multichainWalletId)
        return merchants.filter { providerIds.contains($0.id) }
    }

    func fetchQuotes(
        flow: RampFlow,
        amount: String,
        currencyCode: String,
        paymentMethodType: String,
        merchantId: String?
    ) async throws -> InsertAmountQuotesState {
        switch flow {
        case .deposit:
            let request = OnRampQuoteRequest(
                targetAssetId: assetDetail.assetId,
                fiat: currencyCode,
                amount: amount,
                reverse: nil,
                paymentMethod: paymentMethodType,
                merchantId: merchantId
            )
            let result = try await multichainRampService.onrampQuote(
                request: request,
                walletId: wallet.multichainWalletId
            )
            return InsertAmountQuotesState(
                quotes: result.quotes.compactMap(mapOnRampQuote),
                suggestedQuotes: result.suggestedQuotes.compactMap(mapOnRampQuote)
            )
        case .withdraw:
            let request = OffRampQuoteRequest(
                sourceAssetId: assetDetail.assetId,
                fiat: currencyCode,
                amount: amount,
                reverse: nil,
                payoutMethod: paymentMethodType,
                merchantId: merchantId
            )
            let result = try await multichainRampService.offrampQuote(request: request)
            return InsertAmountQuotesState(
                quotes: result.quotes.compactMap(mapOffRampQuote),
                suggestedQuotes: result.suggestedQuotes.compactMap(mapOffRampQuote)
            )
        }
    }

    func resolveWidgetURL(
        flow: RampFlow,
        amount: String,
        currencyCode: String,
        paymentMethodType: String,
        merchantId: String,
        merchantTransactionId: String
    ) async throws -> URL {
        switch flow {
        case .deposit:
            guard
                let chain = MultichainAssetDetails(
                    assetId: assetDetail.assetId,
                    name: "",
                    symbol: assetDetail.symbol,
                    decimals: assetDetail.decimals,
                    image: ""
                ).chain,
                let destinationAddress = wallet.multichainAddress(for: chain)
            else {
                throw InsertAmountQuoteServiceError.missingDestinationAddress
            }

            let request = OnRampCreateOrderRequest(
                targetAssetId: assetDetail.assetId,
                fiat: currencyCode,
                amount: amount,
                reverse: nil,
                destinationAddress: destinationAddress,
                extraId: nil,
                paymentMethod: paymentMethodType,
                merchantId: merchantId,
                merchantTransactionId: merchantTransactionId,
                redirectUrl: nil,
                language: nil,
                idempotencyKey: UUID().uuidString
            )
            let order = try await multichainRampService.createOnrampOrder(
                request: request,
                walletId: wallet.multichainWalletId
            )
            guard let url = URL(string: order.widgetUrl) else {
                throw InsertAmountQuoteServiceError.missingWidgetURL
            }
            return url
        case .withdraw:
            guard
                let chain = MultichainAssetDetails(
                    assetId: assetDetail.assetId,
                    name: "",
                    symbol: assetDetail.symbol,
                    decimals: assetDetail.decimals,
                    image: ""
                ).chain,
                let fromAddress = wallet.multichainAddress(for: chain)
            else {
                throw InsertAmountQuoteServiceError.missingDestinationAddress
            }

            let request = OffRampCreateOrderRequest(
                sourceAssetId: assetDetail.assetId,
                fiat: currencyCode,
                amount: amount,
                reverse: nil,
                fromAddress: fromAddress,
                extraId: nil,
                payoutMethod: paymentMethodType,
                merchantId: merchantId,
                merchantTransactionId: merchantTransactionId,
                redirectUrl: nil,
                language: nil,
                idempotencyKey: UUID().uuidString
            )
            let order = try await multichainRampService.createOfframpOrder(request: request)
            guard let url = URL(string: order.widgetUrl) else {
                throw InsertAmountQuoteServiceError.missingWidgetURL
            }
            return url
        }
    }

    private func mapOnRampQuote(_ quote: OnRampMerchantQuote) -> InsertAmountMerchantQuote? {
        guard let convertedAmount = Decimal(string: quote.amountOut), convertedAmount > 0 else {
            return nil
        }
        return InsertAmountMerchantQuote(
            merchantId: quote.merchantId,
            merchantTransactionId: quote.merchantTransactionId,
            convertedAmount: convertedAmount,
            amountIn: Decimal(string: quote.amountIn),
            rate: Decimal(string: quote.rate),
            minAmount: quote.minAmount.flatMap(Double.init),
            maxAmount: quote.maxAmount.flatMap(Double.init),
            widgetURL: nil
        )
    }

    private func mapOffRampQuote(_ quote: OffRampMerchantQuote) -> InsertAmountMerchantQuote? {
        guard let convertedAmount = Decimal(string: quote.amountOut), convertedAmount > 0 else {
            return nil
        }
        return InsertAmountMerchantQuote(
            merchantId: quote.merchantId,
            merchantTransactionId: quote.merchantTransactionId,
            convertedAmount: convertedAmount,
            amountIn: Decimal(string: quote.amountIn),
            rate: Decimal(string: quote.rate),
            minAmount: quote.minAmount.flatMap(Double.init),
            maxAmount: quote.maxAmount.flatMap(Double.init),
            widgetURL: nil
        )
    }
}

enum InsertAmountQuoteServiceError: Error {
    case missingWidgetURL
    case missingDestinationAddress
}

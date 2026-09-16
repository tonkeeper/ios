import Foundation

// MARK: - Configuration

public struct OnRampConfigurationQuery: Sendable, Hashable {
    public var destinationChain: String?
    public var fiat: String?
    public var paymentMethod: String?
    public var searchQuery: String?
    public var cursor: String?
    public var limit: Int?

    public init(
        destinationChain: String? = nil,
        fiat: String? = nil,
        paymentMethod: String? = nil,
        searchQuery: String? = nil,
        cursor: String? = nil,
        limit: Int? = nil
    ) {
        self.destinationChain = destinationChain
        self.fiat = fiat
        self.paymentMethod = paymentMethod
        self.searchQuery = searchQuery
        self.cursor = cursor
        self.limit = limit
    }
}

public struct OnRampChainsQuery: Sendable, Hashable {
    public var fiat: String?
    public var paymentMethod: String?

    public init(
        fiat: String? = nil,
        paymentMethod: String? = nil
    ) {
        self.fiat = fiat
        self.paymentMethod = paymentMethod
    }
}

public struct OnRampChains: Equatable, Codable, Sendable {
    /// Internal chain ids (`asset_id` prefixes), ordered by display priority.
    public let chains: [String]

    public init(chains: [String]) {
        self.chains = chains
    }
}

public struct OffRampConfigurationQuery: Sendable, Hashable {
    public var sourceChain: String?
    public var fiat: String?
    public var payoutMethod: String?
    public var searchQuery: String?
    public var cursor: String?
    public var limit: Int?

    public init(
        sourceChain: String? = nil,
        fiat: String? = nil,
        payoutMethod: String? = nil,
        searchQuery: String? = nil,
        cursor: String? = nil,
        limit: Int? = nil
    ) {
        self.sourceChain = sourceChain
        self.fiat = fiat
        self.payoutMethod = payoutMethod
        self.searchQuery = searchQuery
        self.cursor = cursor
        self.limit = limit
    }
}

public struct OnRampConfiguration: Equatable, Codable {
    public let assets: [OnRampConfigurationAsset]
    public let nextCursor: String?

    public init(assets: [OnRampConfigurationAsset], nextCursor: String? = nil) {
        self.assets = assets
        self.nextCursor = nextCursor
    }
}

public struct OnRampConfigurationAsset: Equatable, Codable {
    public let assetId: String
    public let symbol: String
    public let networkName: String?
    public let networkImage: String?
    public let image: String?
    public let decimals: Int
    public let stablecoin: Bool
    public let extraIdRequired: Bool
    public let extraIdName: String?
    public let availableMethods: [String]
    public let availableFiats: [String]
}

public struct OnRampAssetDetail: Equatable, Codable {
    public let assetId: String
    public let symbol: String
    public let networkName: String?
    public let networkImage: String?
    public let image: String?
    public let decimals: Int
    public let stablecoin: Bool
    public let extraIdRequired: Bool
    public let extraIdName: String?
    public let paymentMethods: [OnRampPaymentMethod]
}

public struct OnRampPaymentMethod: Equatable, Codable {
    public let type: String
    public let name: String
    public let image: String
    public let isP2P: Bool
    public let providers: [OnRampProvider]
}

public struct OnRampProvider: Equatable, Codable {
    public let merchantId: String
    public let fiat: String
    public let limits: OnRampLimits?
}

public struct OffRampConfiguration: Equatable, Codable {
    public let assets: [OffRampConfigurationAsset]
    public let nextCursor: String?

    public init(assets: [OffRampConfigurationAsset], nextCursor: String? = nil) {
        self.assets = assets
        self.nextCursor = nextCursor
    }
}

public struct OffRampConfigurationAsset: Equatable, Codable {
    public let assetId: String
    public let symbol: String
    public let networkName: String?
    public let networkImage: String?
    public let image: String?
    public let decimals: Int
    public let stablecoin: Bool
    public let extraIdRequired: Bool
    public let extraIdName: String?
    public let availablePayoutMethods: [String]
    public let availableFiats: [String]
}

public struct OffRampAssetDetail: Equatable, Codable {
    public let assetId: String
    public let symbol: String
    public let networkName: String?
    public let networkImage: String?
    public let image: String?
    public let decimals: Int
    public let stablecoin: Bool
    public let extraIdRequired: Bool
    public let extraIdName: String?
    public let payoutMethods: [OffRampPayoutMethod]
}

public struct OffRampPayoutMethod: Equatable, Codable {
    public let type: String
    public let name: String
    public let image: String
    public let providers: [OffRampProvider]
}

public struct OffRampProvider: Equatable, Codable {
    public let merchantId: String
    public let fiat: String
    public let limits: OnRampLimits?
}

// MARK: - Quotes

public enum OnRampUnavailableReason: String, Equatable, Codable {
    case countryBlocked = "country_blocked"
    case amountBelowMin = "amount_below_min"
    case amountAboveMax = "amount_above_max"
    case noMerchantSupportsPair = "no_merchant_supports_pair"
}

public struct OnRampFees: Equatable, Codable {
    public let provider: String?
    public let network: String?
    public let total: String
}

public struct OnRampMerchantQuote: Equatable {
    public let merchantId: String
    public let paymentMethod: String
    public let amountIn: String
    public let amountOut: String
    public let rate: String
    public let fees: OnRampFees
    public let minAmount: String?
    public let maxAmount: String?
    public let dateExpire: Date
    public let merchantTransactionId: String
}

public struct OnRampQuotesResult: Equatable {
    public let quotes: [OnRampMerchantQuote]
    public let suggestedQuotes: [OnRampMerchantQuote]
    public let unavailableReason: OnRampUnavailableReason?
}

public struct OnRampQuoteRequest: Sendable, Hashable {
    public var targetAssetId: String
    public var fiat: String
    public var amount: String
    public var reverse: Bool?
    public var paymentMethod: String?
    public var merchantId: String?

    public init(
        targetAssetId: String,
        fiat: String,
        amount: String,
        reverse: Bool? = nil,
        paymentMethod: String? = nil,
        merchantId: String? = nil
    ) {
        self.targetAssetId = targetAssetId
        self.fiat = fiat
        self.amount = amount
        self.reverse = reverse
        self.paymentMethod = paymentMethod
        self.merchantId = merchantId
    }
}

public struct OffRampMerchantQuote: Equatable {
    public let merchantId: String
    public let payoutMethod: String
    public let amountIn: String
    public let amountOut: String
    public let rate: String
    public let fees: OnRampFees
    public let minAmount: String?
    public let maxAmount: String?
    public let dateExpire: Date
    public let merchantTransactionId: String
}

public struct OffRampQuotesResult: Equatable {
    public let quotes: [OffRampMerchantQuote]
    public let suggestedQuotes: [OffRampMerchantQuote]
    public let unavailableReason: OnRampUnavailableReason?
}

public struct OffRampQuoteRequest: Sendable, Hashable {
    public var sourceAssetId: String
    public var fiat: String
    public var amount: String
    public var reverse: Bool?
    public var payoutMethod: String?
    public var merchantId: String?

    public init(
        sourceAssetId: String,
        fiat: String,
        amount: String,
        reverse: Bool? = nil,
        payoutMethod: String? = nil,
        merchantId: String? = nil
    ) {
        self.sourceAssetId = sourceAssetId
        self.fiat = fiat
        self.amount = amount
        self.reverse = reverse
        self.payoutMethod = payoutMethod
        self.merchantId = merchantId
    }
}

// MARK: - Orders

public enum OnRampOrderStatus: String, Equatable, Codable {
    case created
    case awaitingPayment = "awaiting_payment"
    case paymentReceived = "payment_received"
    case fundsSent = "funds_sent"
    case completed
    case failed
    case cancelled
    case expired
    case refunded
}

public struct OnRampCreateOrderRequest: Sendable, Hashable {
    public var targetAssetId: String
    public var fiat: String
    public var amount: String
    public var reverse: Bool?
    public var destinationAddress: String
    public var extraId: String?
    public var paymentMethod: String
    public var merchantId: String
    public var merchantTransactionId: String?
    public var redirectUrl: String?
    public var language: String?
    public var idempotencyKey: String?

    public init(
        targetAssetId: String,
        fiat: String,
        amount: String,
        reverse: Bool? = nil,
        destinationAddress: String,
        extraId: String? = nil,
        paymentMethod: String,
        merchantId: String,
        merchantTransactionId: String? = nil,
        redirectUrl: String? = nil,
        language: String? = nil,
        idempotencyKey: String? = nil
    ) {
        self.targetAssetId = targetAssetId
        self.fiat = fiat
        self.amount = amount
        self.reverse = reverse
        self.destinationAddress = destinationAddress
        self.extraId = extraId
        self.paymentMethod = paymentMethod
        self.merchantId = merchantId
        self.merchantTransactionId = merchantTransactionId
        self.redirectUrl = redirectUrl
        self.language = language
        self.idempotencyKey = idempotencyKey
    }
}

public struct OnRampOrder: Equatable {
    public let id: String
    public let merchantId: String
    public let merchantTransactionId: String?
    public let status: OnRampOrderStatus
    public let statusReason: String?
    public let widgetUrl: String
    public let destinationAddress: String
    public let destinationExtraId: String?
    public let extraIdName: String?
    public let amountIn: String
    public let amountOut: String
    public let rate: String
    public let fees: OnRampFees
    public let destinationTxHash: String?
    public let providerOrderId: String?
    public let estimatedDuration: Int?
    public let dateCreate: Date
    public let dateUpdate: Date?
}

public enum OffRampOrderStatus: String, Equatable, Codable {
    case created
    case awaitingFunds = "awaiting_funds"
    case fundsReceived = "funds_received"
    case completed
    case failed
    case cancelled
    case expired
    case refunded
}

public struct OffRampCreateOrderRequest: Sendable, Hashable {
    public var sourceAssetId: String
    public var fiat: String
    public var amount: String
    public var reverse: Bool?
    public var fromAddress: String
    public var extraId: String?
    public var payoutMethod: String
    public var merchantId: String
    public var merchantTransactionId: String?
    public var redirectUrl: String?
    public var language: String?
    public var idempotencyKey: String?

    public init(
        sourceAssetId: String,
        fiat: String,
        amount: String,
        reverse: Bool? = nil,
        fromAddress: String,
        extraId: String? = nil,
        payoutMethod: String,
        merchantId: String,
        merchantTransactionId: String? = nil,
        redirectUrl: String? = nil,
        language: String? = nil,
        idempotencyKey: String? = nil
    ) {
        self.sourceAssetId = sourceAssetId
        self.fiat = fiat
        self.amount = amount
        self.reverse = reverse
        self.fromAddress = fromAddress
        self.extraId = extraId
        self.payoutMethod = payoutMethod
        self.merchantId = merchantId
        self.merchantTransactionId = merchantTransactionId
        self.redirectUrl = redirectUrl
        self.language = language
        self.idempotencyKey = idempotencyKey
    }
}

public struct OffRampOrder: Equatable {
    public let id: String
    public let merchantId: String
    public let merchantTransactionId: String?
    public let status: OffRampOrderStatus
    public let statusReason: String?
    public let widgetUrl: String
    public let payinAddress: String
    public let payinExtraId: String?
    public let extraIdName: String?
    public let amountIn: String
    public let amountOut: String
    public let rate: String
    public let fees: OnRampFees
    public let depositTxHash: String?
    public let refundTxHash: String?
    public let refundAddress: String?
    public let providerOrderId: String?
    public let estimatedDuration: Int?
    public let dateCreate: Date
    public let dateUpdate: Date?
}

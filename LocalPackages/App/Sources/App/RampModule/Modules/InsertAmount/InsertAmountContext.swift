import Foundation
import KeeperCore

struct InsertAmountPaymentMethodContext {
    let type: String
    let providers: [InsertAmountProviderContext]

    init(_ paymentMethod: OnRampLayoutCashMethod) {
        type = paymentMethod.type
        providers = paymentMethod.providers.map {
            InsertAmountProviderContext(merchantId: $0.slug, limits: $0.limits)
        }
    }

    init(_ paymentMethod: OnRampPaymentMethod, currencyCode: String) {
        type = paymentMethod.type
        providers = paymentMethod.providers
            .filter { $0.fiat == currencyCode }
            .map {
                InsertAmountProviderContext(merchantId: $0.merchantId, limits: $0.limits)
            }
    }
}

struct InsertAmountProviderContext {
    let merchantId: String
    let limits: OnRampLimits?
}

enum InsertAmountAssetContext {
    case legacy(RampAsset)
    case multichain(MultichainAsset)

    var symbol: String {
        switch self {
        case let .legacy(asset):
            return asset.symbol
        case let .multichain(asset):
            return asset.asset.symbol
        }
    }

    var decimals: Int {
        switch self {
        case let .legacy(asset):
            return asset.decimals
        case let .multichain(asset):
            return asset.asset.decimals
        }
    }

    /// Fiat per one asset unit from the asset's own market price, in `currencyCode`. Used as the
    /// converted-amount rate when no quote can price the entered amount (out of provider limits,
    /// or before the first quote). Prices are only loaded for the wallet currency and USD, so a
    /// ramp currency outside that pair has none.
    func marketRate(currencyCode: String) -> Decimal? {
        guard case let .multichain(asset) = self else { return nil }
        let price = asset.price.prices[currencyCode]
            ?? asset.price.prices[currencyCode.lowercased()]
            ?? asset.price.prices[currencyCode.uppercased()]
        guard let price, price > 0 else { return nil }
        return Decimal(price)
    }

    var depositAnalyticsAssetIdentifier: String? {
        switch self {
        case let .legacy(asset):
            return asset.depositAnalyticsAssetIdentifier
        case let .multichain(asset):
            return asset.asset.assetId
        }
    }

    var withdrawAnalyticsAssetIdentifier: String? {
        switch self {
        case let .legacy(asset):
            return asset.withdrawAnalyticsAssetIdentifier
        case let .multichain(asset):
            return asset.asset.assetId
        }
    }
}

struct InsertAmountMerchantQuote {
    let merchantId: String
    let merchantTransactionId: String
    let convertedAmount: Decimal
    /// Source amount the server actually quoted; differs from the requested amount when clamped into provider limits.
    let amountIn: Decimal?
    /// Server rate, `amountOut / amountIn` for both flows. `nil` for legacy quotes.
    let rate: Decimal?
    let minAmount: Double?
    let maxAmount: Double?
    let widgetURL: URL?
}

struct InsertAmountQuotesState {
    let quotes: [InsertAmountMerchantQuote]
    let suggestedQuotes: [InsertAmountMerchantQuote]
}

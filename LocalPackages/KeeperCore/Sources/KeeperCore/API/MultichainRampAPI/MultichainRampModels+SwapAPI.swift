import Foundation
import SwapAPI

// MARK: - Configuration

extension OnRampChains {
    init(api: SwapAPI.Components.Schemas.OnrampChains) {
        self.chains = api.chains
    }
}

extension OnRampConfiguration {
    init(api: SwapAPI.Components.Schemas.OnrampConfiguration) {
        self.assets = api.assets.map { OnRampConfigurationAsset(api: $0) }
        self.nextCursor = api.next_cursor
    }
}

extension OnRampConfigurationAsset {
    init(api: SwapAPI.Components.Schemas.OnrampAsset) {
        self.assetId = api.asset_id
        self.symbol = api.symbol
        self.networkName = api.network_name
        self.networkImage = api.network_image
        self.image = api.image
        self.decimals = api.decimals
        self.stablecoin = api.stablecoin
        self.extraIdRequired = api.extra_id_required
        self.extraIdName = api.extra_id_name
        self.availableMethods = api.available_methods.map(\.rawValue)
        self.availableFiats = api.available_fiats
    }
}

extension OnRampAssetDetail {
    init(api: SwapAPI.Components.Schemas.OnrampAssetDetail) {
        self.assetId = api.asset_id
        self.symbol = api.symbol
        self.networkName = api.network_name
        self.networkImage = api.network_image
        self.image = api.image
        self.decimals = api.decimals
        self.stablecoin = api.stablecoin
        self.extraIdRequired = api.extra_id_required
        self.extraIdName = api.extra_id_name
        self.paymentMethods = api.payment_methods.map { OnRampPaymentMethod(api: $0) }
    }
}

extension OnRampPaymentMethod {
    init(api: SwapAPI.Components.Schemas.OnrampPaymentMethod) {
        self.type = api._type.rawValue
        self.name = api.name
        self.image = api.image
        self.isP2P = api._type == .p2p
        self.providers = api.providers.map { OnRampProvider(api: $0) }
    }
}

extension OnRampProvider {
    init(api: SwapAPI.Components.Schemas.OnrampProvider) {
        self.merchantId = api.merchant.rawValue
        self.fiat = api.fiat
        self.limits = api.limits.map { OnRampLimits(api: $0) }
    }
}

extension OffRampConfiguration {
    init(api: SwapAPI.Components.Schemas.OfframpConfiguration) {
        self.assets = api.assets.map { OffRampConfigurationAsset(api: $0) }
        self.nextCursor = api.next_cursor
    }
}

extension OffRampConfigurationAsset {
    init(api: SwapAPI.Components.Schemas.OfframpAsset) {
        self.assetId = api.asset_id
        self.symbol = api.symbol
        self.networkName = api.network_name
        self.networkImage = api.network_image
        self.image = api.image
        self.decimals = api.decimals
        self.stablecoin = api.stablecoin
        self.extraIdRequired = api.extra_id_required
        self.extraIdName = api.extra_id_name
        self.availablePayoutMethods = api.available_payout_methods.map(\.rawValue)
        self.availableFiats = api.available_fiats
    }
}

extension OffRampAssetDetail {
    init(api: SwapAPI.Components.Schemas.OfframpAssetDetail) {
        self.assetId = api.asset_id
        self.symbol = api.symbol
        self.networkName = api.network_name
        self.networkImage = api.network_image
        self.image = api.image
        self.decimals = api.decimals
        self.stablecoin = api.stablecoin
        self.extraIdRequired = api.extra_id_required
        self.extraIdName = api.extra_id_name
        self.payoutMethods = api.payout_methods.map { OffRampPayoutMethod(api: $0) }
    }
}

public extension OffRampAssetDetail {
    var paymentMethodAssetDetail: OnRampAssetDetail {
        OnRampAssetDetail(
            assetId: assetId,
            symbol: symbol,
            networkName: networkName,
            networkImage: networkImage,
            image: image,
            decimals: decimals,
            stablecoin: stablecoin,
            extraIdRequired: extraIdRequired,
            extraIdName: extraIdName,
            paymentMethods: payoutMethods.map(\.paymentMethodAssetDetail)
        )
    }
}

extension OffRampPayoutMethod {
    var paymentMethodAssetDetail: OnRampPaymentMethod {
        OnRampPaymentMethod(
            type: type,
            name: name,
            image: image,
            isP2P: type.lowercased() == "p2p",
            providers: providers.map(\.paymentMethodProvider)
        )
    }
}

extension OffRampProvider {
    var paymentMethodProvider: OnRampProvider {
        OnRampProvider(
            merchantId: merchantId,
            fiat: fiat,
            limits: limits
        )
    }
}

extension OffRampPayoutMethod {
    init(api: SwapAPI.Components.Schemas.OfframpPayoutMethod) {
        self.type = api._type.rawValue
        self.name = api.name
        self.image = api.image
        self.providers = api.providers.map { OffRampProvider(api: $0) }
    }
}

extension OffRampProvider {
    init(api: SwapAPI.Components.Schemas.OfframpProvider) {
        self.merchantId = api.merchant.rawValue
        self.fiat = api.fiat
        self.limits = api.limits.map { OnRampLimits(api: $0) }
    }
}

// MARK: - Quotes

extension OnRampFees {
    init(api: SwapAPI.Components.Schemas.RampFees) {
        self.provider = api.provider
        self.network = api.network
        self.total = api.total
    }
}

extension OnRampUnavailableReason {
    init?(api: SwapAPI.Components.Schemas.RampUnavailableReason) {
        self.init(rawValue: api.rawValue)
    }
}

extension OnRampMerchantQuote {
    init(api: SwapAPI.Components.Schemas.OnrampQuoteResult) {
        self.merchantId = api.merchant.rawValue
        self.paymentMethod = api.payment_method.rawValue
        self.amountIn = api.amount_in
        self.amountOut = api.amount_out
        self.rate = api.rate
        self.fees = OnRampFees(api: api.fees)
        self.minAmount = api.min_amount
        self.maxAmount = api.max_amount
        self.dateExpire = api.date_expire
        self.merchantTransactionId = api.merchant_transaction_id
    }
}

extension OnRampQuotesResult {
    init(api: SwapAPI.Components.Schemas.OnrampQuotes) {
        self.quotes = api.items.map { OnRampMerchantQuote(api: $0) }
        self.suggestedQuotes = api.suggested.map { OnRampMerchantQuote(api: $0) }
        self.unavailableReason = api.unavailable_reason.flatMap { OnRampUnavailableReason(api: $0) }
    }
}

extension OnRampQuoteRequest {
    func swapAPIRequestBody() -> SwapAPI.Components.RequestBodies.OnrampQuote {
        .json(
            .init(
                target_asset_id: targetAssetId,
                fiat: fiat,
                amount: amount,
                reverse: reverse,
                payment_method: paymentMethod.flatMap { SwapAPI.Components.Schemas.ExchangePaymentMethodType(rawValue: $0) },
                merchant: merchantId.flatMap { SwapAPI.Components.Schemas.ExchangeMerchantSlug(rawValue: $0) }
            )
        )
    }
}

extension OffRampMerchantQuote {
    init(api: SwapAPI.Components.Schemas.OfframpQuoteResult) {
        self.merchantId = api.merchant.rawValue
        self.payoutMethod = api.payout_method.rawValue
        self.amountIn = api.amount_in
        self.amountOut = api.amount_out
        self.rate = api.rate
        self.fees = OnRampFees(api: api.fees)
        self.minAmount = api.min_amount
        self.maxAmount = api.max_amount
        self.dateExpire = api.date_expire
        self.merchantTransactionId = api.merchant_transaction_id
    }
}

extension OffRampQuotesResult {
    init(api: SwapAPI.Components.Schemas.OfframpQuotes) {
        self.quotes = api.items.map { OffRampMerchantQuote(api: $0) }
        self.suggestedQuotes = api.suggested.map { OffRampMerchantQuote(api: $0) }
        self.unavailableReason = api.unavailable_reason.flatMap { OnRampUnavailableReason(api: $0) }
    }
}

extension OffRampQuoteRequest {
    func swapAPIRequestBody() -> SwapAPI.Components.RequestBodies.OfframpQuote {
        .json(
            .init(
                source_asset_id: sourceAssetId,
                fiat: fiat,
                amount: amount,
                reverse: reverse,
                payout_method: payoutMethod.flatMap { SwapAPI.Components.Schemas.ExchangePaymentMethodType(rawValue: $0) },
                merchant: merchantId.flatMap { SwapAPI.Components.Schemas.ExchangeMerchantSlug(rawValue: $0) }
            )
        )
    }
}

// MARK: - Orders

extension OnRampOrderStatus {
    init(api: SwapAPI.Components.Schemas.OnrampOrderStatus) {
        self = OnRampOrderStatus(rawValue: api.rawValue) ?? .created
    }
}

extension OnRampOrder {
    init(api: SwapAPI.Components.Schemas.OnrampOrder) {
        self.id = api.id
        self.merchantId = api.merchant.rawValue
        self.merchantTransactionId = api.merchant_transaction_id
        self.status = OnRampOrderStatus(api: api.status)
        self.statusReason = api.status_reason
        self.widgetUrl = api.widget_url
        self.destinationAddress = api.destination_address
        self.destinationExtraId = api.destination_extra_id
        self.extraIdName = api.extra_id_name
        self.amountIn = api.amount_in
        self.amountOut = api.amount_out
        self.rate = api.rate
        self.fees = OnRampFees(api: api.fees)
        self.destinationTxHash = api.destination_tx_hash
        self.providerOrderId = api.provider_order_id
        self.estimatedDuration = api.estimated_duration
        self.dateCreate = api.date_create
        self.dateUpdate = api.date_update
    }
}

extension OnRampCreateOrderRequest {
    func swapAPIRequestBody() -> SwapAPI.Components.RequestBodies.OnrampCreate {
        .json(
            .init(
                target_asset_id: targetAssetId,
                fiat: fiat,
                amount: amount,
                reverse: reverse,
                destination_address: destinationAddress,
                extra_id: extraId,
                payment_method: SwapAPI.Components.Schemas.ExchangePaymentMethodType(rawValue: paymentMethod) ?? .card,
                merchant: SwapAPI.Components.Schemas.ExchangeMerchantSlug(rawValue: merchantId) ?? .mercuryo,
                merchant_transaction_id: merchantTransactionId,
                redirect_url: redirectUrl,
                language: language
            )
        )
    }
}

extension OffRampOrderStatus {
    init(api: SwapAPI.Components.Schemas.OfframpOrderStatus) {
        self = OffRampOrderStatus(rawValue: api.rawValue) ?? .created
    }
}

extension OffRampOrder {
    init(api: SwapAPI.Components.Schemas.OfframpOrder) {
        self.id = api.id
        self.merchantId = api.merchant.rawValue
        self.merchantTransactionId = api.merchant_transaction_id
        self.status = OffRampOrderStatus(api: api.status)
        self.statusReason = api.status_reason
        self.widgetUrl = api.widget_url
        self.payinAddress = api.payin_address
        self.payinExtraId = api.payin_extra_id
        self.extraIdName = api.extra_id_name
        self.amountIn = api.amount_in
        self.amountOut = api.amount_out
        self.rate = api.rate
        self.fees = OnRampFees(api: api.fees)
        self.depositTxHash = api.deposit_tx_hash
        self.refundTxHash = api.refund_tx_hash
        self.refundAddress = api.refund_address
        self.providerOrderId = api.provider_order_id
        self.estimatedDuration = api.estimated_duration
        self.dateCreate = api.date_create
        self.dateUpdate = api.date_update
    }
}

extension OffRampCreateOrderRequest {
    func swapAPIRequestBody() -> SwapAPI.Components.RequestBodies.OfframpCreate {
        .json(
            .init(
                source_asset_id: sourceAssetId,
                fiat: fiat,
                amount: amount,
                reverse: reverse,
                from_address: fromAddress,
                extra_id: extraId,
                payout_method: SwapAPI.Components.Schemas.ExchangePaymentMethodType(rawValue: payoutMethod) ?? .card,
                merchant: SwapAPI.Components.Schemas.ExchangeMerchantSlug(rawValue: merchantId) ?? .mercuryo,
                merchant_transaction_id: merchantTransactionId,
                redirect_url: redirectUrl,
                language: language
            )
        )
    }
}

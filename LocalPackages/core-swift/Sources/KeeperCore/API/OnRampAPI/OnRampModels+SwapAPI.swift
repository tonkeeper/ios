import Foundation
import SwapAPI

extension OnRampLimits {
    init(api: SwapAPI.Components.Schemas.ExchangeLimits) {
        self.min = api.min ?? 0
        self.max = api.max
    }
}

// MARK: - Merchants (v2/onramp/merchants)

extension OnRampMerchantInfoButton {
    init(api: SwapAPI.Components.Schemas.ExchangeMerchantInfoButton) {
        self.title = api.title
        self.url = api.url
    }
}

extension OnRampMerchantInfo {
    init(api: SwapAPI.Components.Schemas.ExchangeMerchantInfo) {
        self.id = api.id
        self.title = api.title
        self.description = api.description
        self.image = api.image
        self.fee = api.fee
        self.isP2P = api.id == SwapAPI.Components.Schemas.ExchangeMerchantSlug.wallet.rawValue
        self.buttons = api.buttons.map { OnRampMerchantInfoButton(api: $0) }
    }
}

extension OnRampQuoteResult {
    init(api: SwapAPI.Components.Schemas.ExchangeQuote) {
        self.merchantId = api.merchant.rawValue
        self.widgetUrl = api.widget_url
        self.amount = api.amount
        self.fromAmount = api.from_amount
        self.minAmount = api.min_amount
        self.maxAmount = api.max_amount
    }
}

// MARK: - Layout (v2/onramp/layout)

extension OnRampLayout {
    init(api: SwapAPI.Components.Schemas.ExchangeLayout) {
        self.assets = api.assets.map { OnRampLayoutToken(api: $0) }
    }
}

extension OnRampLayoutToken {
    init(api: SwapAPI.Components.Schemas.ExchangeLayoutAsset) {
        self.symbol = api.symbol
        self.assetId = api.asset_id
        self.address = api.address
        self.network = api.network
        self.networkName = api.network_name
        self.networkImage = api.network_image
        self.image = api.image
        self.decimals = api.decimals
        self.stablecoin = api.stablecoin
        self.cashMethods = api.cash_methods.map { OnRampLayoutCashMethod(api: $0) }
        self.cryptoMethods = api.crypto_methods.map { OnRampLayoutCryptoMethod(api: $0) }
    }
}

extension OnRampLayoutCashMethod {
    init(api: SwapAPI.Components.Schemas.ExchangeLayoutCashMethod) {
        self.type = api._type.rawValue
        self.name = api.name
        self.image = api.image
        self.providers = api.providers.map { OnRampLayoutProvider(api: $0) }
        self.isP2P = api._type == .p2p
    }
}

extension OnRampLayoutCryptoMethod {
    init(api: SwapAPI.Components.Schemas.ExchangeLayoutCryptoMethod) {
        self.symbol = api.symbol
        self.assetId = api.asset_id
        self.network = api.network
        self.networkName = api.network_name
        self.networkImage = api.network_image
        self.image = api.image
        self.decimals = api.decimals
        self.stablecoin = api.stablecoin
        self.fee = api.fee
        self.minAmount = api.min_amount
        self.providers = api.providers.map { OnRampLayoutProvider(api: $0) }
    }
}

extension OnRampLayoutProvider {
    init(api: SwapAPI.Components.Schemas.ExchangeLayoutProvider) {
        self.slug = api.slug.rawValue
        self.limits = api.limits.map { OnRampLimits(api: $0) }
    }
}

extension OnRampExchangeResult {
    init(api: SwapAPI.Components.Schemas.ExchangeResult) {
        self.id = api.id
        self.payinAddress = api.payin_address
        self.amountExpectedFrom = api.amount_expected_from
        self.amountExpectedTo = api.amount_expected_to
        self.status = api.status
        self.minDeposit = api.min_deposit
        self.maxDeposit = api.max_deposit
        self.rate = api.rate
        self.estimatedDuration = api.estimated_duration
    }
}

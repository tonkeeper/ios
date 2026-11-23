import Foundation
import KeeperCore

struct RampMerchantMethods {
    let detail: OnRampAssetDetail
    let rows: [RampPaymentMethodRow]
}

/// A merchant the ramp can buy through, with the payment methods it takes for the asset and currency.
struct RampMerchantProvider: Equatable {
    let id: String
    let title: String
    let imageURL: URL?
    let methodTitles: [String]

    var isMoonPay: Bool {
        Self.isMoonPay(merchantId: id)
    }

    /// MoonPay's widget sold through our backend; the native MoonPay takes its place once the
    /// customer has signed in to it.
    static func isMoonPay(merchantId: String) -> Bool {
        merchantId.lowercased().contains("moonpay")
    }
}

struct RampMerchantsContext {
    let providers: [OnRampProvider]
    let merchants: [OnRampMerchantInfo]
}

@MainActor
struct RampMerchantService {
    let wallet: Wallet
    let multichainRampService: MultichainRampService
    let onRampService: OnRampService

    func defaultAsset(fiat: String) async throws -> MultichainAsset? {
        let configuration = try await multichainRampService.getOnrampConfiguration(
            query: OnRampConfigurationQuery(fiat: fiat, searchQuery: "USDT", limit: 30),
            walletId: wallet.multichainWalletId
        )
        let assets = configuration.assets.map { configurationAsset -> MultichainAsset in
            let details = MultichainAssetDetails(
                assetId: configurationAsset.assetId,
                name: configurationAsset.networkName ?? "",
                symbol: configurationAsset.symbol,
                decimals: configurationAsset.decimals,
                image: configurationAsset.image ?? ""
            )
            return MultichainAsset(
                asset: details,
                price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
                balance: .zero
            )
        }
        let usable = assets.filter { $0.asset.chain != nil }
        return usable.first { $0.asset.assetId.hasPrefix("ton/") && $0.asset.symbol.uppercased() == "USDT" } ?? usable.first
    }

    func methods(asset: MultichainAsset, fiat: String) async throws -> RampMerchantMethods {
        let detail = try await multichainRampService.getOnrampAsset(
            assetId: asset.asset.assetId,
            fiat: fiat,
            walletId: wallet.multichainWalletId
        )
        return RampMerchantMethods(detail: detail, rows: RampPaymentMethodRow.rows(from: detail, fiat: fiat))
    }

    func providers(asset: MultichainAsset, fiat: String) async throws -> [RampMerchantProvider] {
        let detail = try await methods(asset: asset, fiat: fiat).detail
        let ids = Self.merchantIds(in: detail, fiat: fiat)
        guard !ids.isEmpty else { return [] }
        let merchants = try await quoteService(detail: detail).loadMerchants(providerIds: ids)
        return Self.providers(detail: detail, merchants: merchants, fiat: fiat)
    }

    /// P2P is a payment method of its own, not a provider to buy through.
    static func providers(
        detail: OnRampAssetDetail,
        merchants: [OnRampMerchantInfo],
        fiat: String
    ) -> [RampMerchantProvider] {
        let methods = detail.paymentMethods.filter { !$0.isP2P }
        return merchants.filter { !$0.isP2P }.compactMap { merchant in
            let titles = methods
                .filter { method in method.providers.contains { $0.merchantId == merchant.id && $0.fiat == fiat } }
                .map(\.name)
            guard !titles.isEmpty else { return nil }
            return RampMerchantProvider(
                id: merchant.id,
                title: merchant.title,
                imageURL: URL(string: merchant.image),
                methodTitles: titles
            )
        }
    }

    /// The payment method types the merchant takes for the currency.
    static func methodTypes(of merchantId: String, in detail: OnRampAssetDetail, fiat: String) -> Set<String> {
        Set(detail.paymentMethods
            .filter { method in method.providers.contains { $0.merchantId == merchantId && $0.fiat == fiat } }
            .map(\.type))
    }

    /// The payment method types MoonPay's widget takes for the currency: MoonPay's methods as far as
    /// they are known before the sign-in to the native MoonPay.
    static func moonPayWidgetMethodTypes(in detail: OnRampAssetDetail, fiat: String) -> Set<String> {
        Set(detail.paymentMethods
            .filter { method in
                method.providers.contains { $0.fiat == fiat && RampMerchantProvider.isMoonPay(merchantId: $0.merchantId) }
            }
            .map(\.type))
    }

    /// Unknown methods (nil) are not taken: the sign-in is offered only where the backend says
    /// MoonPay sells.
    static func moonPayWidgetTakes(methodType: String?, among widgetTypes: Set<String>?) -> Bool {
        guard let methodType, let widgetTypes else { return false }
        return widgetTypes.contains(methodType)
    }

    private static func merchantIds(in detail: OnRampAssetDetail, fiat: String) -> [String] {
        var seen = Set<String>()
        return detail.paymentMethods
            .filter { !$0.isP2P }
            .flatMap(\.providers)
            .filter { $0.fiat == fiat }
            .map(\.merchantId)
            .filter { seen.insert($0).inserted }
    }

    func merchants(detail: OnRampAssetDetail, methodType: String, fiat: String) async throws -> RampMerchantsContext {
        let providers = detail.paymentMethods
            .first { $0.type == methodType }?
            .providers
            .filter { $0.fiat == fiat } ?? []
        let merchants = try await quoteService(detail: detail).loadMerchants(providerIds: providers.map(\.merchantId))
        return RampMerchantsContext(providers: providers, merchants: merchants)
    }

    func quotes(
        detail: OnRampAssetDetail,
        amount: String,
        fiat: String,
        methodType: String
    ) async throws -> InsertAmountQuotesState {
        try await quoteService(detail: detail).fetchQuotes(
            flow: .deposit,
            amount: amount,
            currencyCode: fiat,
            paymentMethodType: methodType,
            merchantId: nil
        )
    }

    func widgetURL(
        detail: OnRampAssetDetail,
        amount: String,
        fiat: String,
        methodType: String,
        quote: InsertAmountMerchantQuote
    ) async throws -> URL {
        try await quoteService(detail: detail).resolveWidgetURL(
            flow: .deposit,
            amount: amount,
            currencyCode: fiat,
            paymentMethodType: methodType,
            merchantId: quote.merchantId,
            merchantTransactionId: quote.merchantTransactionId
        )
    }

    private func quoteService(detail: OnRampAssetDetail) -> MultichainInsertAmountQuoteService {
        MultichainInsertAmountQuoteService(
            wallet: wallet,
            assetDetail: detail,
            multichainRampService: multichainRampService,
            onRampService: onRampService
        )
    }
}

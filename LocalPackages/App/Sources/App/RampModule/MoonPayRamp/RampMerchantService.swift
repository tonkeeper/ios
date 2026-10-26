import Foundation
import KeeperCore
import TKLocalize

extension RampPaymentMethodRow {
    // TODO: replace with the backend field once `OnrampPaymentMethod` returns a subtitle.
    var subtitle: String {
        TKLocales.Ramp.Moonpay.PaymentMethod.instant
    }
}

struct RampMerchantMethods {
    let detail: OnRampAssetDetail
    let rows: [RampPaymentMethodRow]
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

import Foundation
import SwapAPI
import TKLocalize

protocol OnRampAPI {
    func getMerchants() async throws -> [OnRampMerchantInfo]
    func getLayout(flow: String, currency: String?) async throws -> OnRampLayout
    func calculate(
        from: String,
        to: String,
        amount: String,
        walletAddress: String,
        purchaseType: OnRampPurchaseType,
        fromNetwork: String?,
        toNetwork: String?,
        paymentMethodType: String?
    ) async throws -> OnRampCalculateResult
    func createOnRampExchange(
        from: String,
        to: String,
        fromNetwork: String?,
        toNetwork: String?,
        walletAddress: String
    ) async throws -> OnRampExchangeResult
    func createP2PSession(data: CreateP2PSession) async throws -> P2PSessionResult
}

final class OnRampAPIImplementation: OnRampAPI {
    private let swapAPIClient: SwapAPI.Client
    private let appInfoProvider: AppInfoProvider

    init(
        swapAPIClient: SwapAPI.Client,
        appInfoProvider: AppInfoProvider
    ) {
        self.swapAPIClient = swapAPIClient
        self.appInfoProvider = appInfoProvider
    }

    func getMerchants() async throws -> [OnRampMerchantInfo] {
        let query = await buildMerchantsQuery()
        let input = SwapAPI.Operations.getExchangeMerchants.Input(query: query)
        do {
            let output = try await swapAPIClient.getExchangeMerchants(input)
            let apiList = try output.ok.body.json
            return apiList.map { OnRampMerchantInfo(api: $0) }
        } catch {
            throw error
        }
    }

    func getLayout(flow: String, currency: String?) async throws -> OnRampLayout {
        let query = await buildLayoutQuery(flow: flow, currency: currency)
        let input = SwapAPI.Operations.getExchangeLayout.Input(query: query)
        let output = try await swapAPIClient.getExchangeLayout(input)
        let apiResult = try output.ok.body.json
        return OnRampLayout(api: apiResult)
    }

    func calculate(
        from: String,
        to: String,
        amount: String,
        walletAddress: String,
        purchaseType: OnRampPurchaseType,
        fromNetwork: String?,
        toNetwork: String?,
        paymentMethodType: String?
    ) async throws -> OnRampCalculateResult {
        let query = await buildCalculateQuery()
        let purchaseTypeAPI = SwapAPI.Components.Schemas.ExchangeDirection(rawValue: purchaseType.rawValue) ?? .buy
        let paymentMethodAPI = paymentMethodType.flatMap { SwapAPI.Components.Schemas.ExchangePaymentMethodType(rawValue: $0) }

        let body = SwapAPI.Components.RequestBodies.ExchangeCalculate.json(.init(
            from: from,
            to: to,
            from_network: fromNetwork,
            to_network: toNetwork,
            amount: amount,
            wallet: walletAddress,
            purchase_type: purchaseTypeAPI,
            payment_method: paymentMethodAPI
        ))

        let input = SwapAPI.Operations.exchangeCalculate.Input(query: query, body: body)
        let output = try await swapAPIClient.exchangeCalculate(input)
        let apiResult = try output.ok.body.json
        let quotes = apiResult.items.map { OnRampQuoteResult(api: $0) }
        let suggestedQuotes = apiResult.suggested.map { OnRampQuoteResult(api: $0) }

        return OnRampCalculateResult(quotes: quotes, suggestedQuotes: suggestedQuotes)
    }

    func createOnRampExchange(
        from: String,
        to: String,
        fromNetwork: String?,
        toNetwork: String?,
        walletAddress: String
    ) async throws -> OnRampExchangeResult {
        let query = await buildCreateExchangeQuery()
        let body = SwapAPI.Components.RequestBodies.CreateExchange.json(
            .init(
                from: from,
                to: to,
                from_network: fromNetwork,
                to_network: toNetwork,
                wallet: walletAddress
            )
        )

        let input = SwapAPI.Operations.createExchange.Input(query: query, body: body)
        let output = try await swapAPIClient.createExchange(input)
        let apiResult = try requireOnRampOk(output)
        return OnRampExchangeResult(api: apiResult)
    }

    func createP2PSession(data: CreateP2PSession) async throws -> P2PSessionResult {
        let body = SwapAPI.Components.RequestBodies.CreateP2PSession.json(
            .init(
                wallet: data.wallet,
                network: data.network,
                crypto_currency: data.cryptoCurrency,
                fiat_currency: data.fiatCurrency,
                amount: data.amount.map { Double($0) }
            )
        )
        let input = SwapAPI.Operations.createP2PSession.Input(body: body)
        let output = try await swapAPIClient.createP2PSession(input)
        let apiResult = try requireOnRampOk(output)
        return P2PSessionResult(
            deeplinkUrl: apiResult.deeplink_url,
            dateExpire: apiResult.date_expire
        )
    }

    private func buildCalculateQuery() async -> SwapAPI.Operations.exchangeCalculate.Input.Query {
        let storeCountry = await appInfoProvider.storeCountryCode
        let platform = SwapAPI.Components.Schemas.Platform(rawValue: appInfoProvider.platform) ?? .ios
        return SwapAPI.Operations.exchangeCalculate.Input.Query(
            device_country_code: appInfoProvider.deviceCountryCode,
            store_country_code: storeCountry,
            build: appInfoProvider.version,
            platform: platform
        )
    }

    private func buildCreateExchangeQuery() async -> SwapAPI.Operations.createExchange.Input.Query {
        let storeCountry = await appInfoProvider.storeCountryCode
        let platform = SwapAPI.Components.Schemas.Platform(rawValue: appInfoProvider.platform) ?? .ios
        return SwapAPI.Operations.createExchange.Input.Query(
            device_country_code: appInfoProvider.deviceCountryCode,
            store_country_code: storeCountry,
            build: appInfoProvider.version,
            platform: platform
        )
    }

    private func buildMerchantsQuery() async -> SwapAPI.Operations.getExchangeMerchants.Input.Query {
        let storeCountry = await appInfoProvider.storeCountryCode
        let platform = SwapAPI.Components.Schemas.Platform(rawValue: appInfoProvider.platform) ?? .ios
        return SwapAPI.Operations.getExchangeMerchants.Input.Query(
            lang: appInfoProvider.language,
            device_country_code: appInfoProvider.deviceCountryCode,
            store_country_code: storeCountry,
            build: appInfoProvider.version,
            platform: platform
        )
    }

    private func buildLayoutQuery(flow: String, currency: String?) async -> SwapAPI.Operations.getExchangeLayout.Input.Query {
        let storeCountry = await appInfoProvider.storeCountryCode
        let platform = SwapAPI.Components.Schemas.Platform(rawValue: appInfoProvider.platform) ?? .ios
        let flowAPI = SwapAPI.Components.Schemas.ExchangeFlow(rawValue: flow) ?? .deposit
        return SwapAPI.Operations.getExchangeLayout.Input.Query(
            flow: flowAPI,
            currency: currency,
            device_country_code: appInfoProvider.deviceCountryCode,
            store_country_code: storeCountry,
            sim_country: nil,
            timezone: nil,
            is_vpn_active: nil,
            platform: platform
        )
    }
}

/// [DEPOSIT] TODO: - fix after testing or make human readble error from backend
private enum OnRampAPIClientError {
    static func nsError(badRequest: SwapAPI.Components.Responses.BadRequest) throws -> NSError {
        try NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: badRequest.body.json.error])
    }

    static func nsError(internalServerError: SwapAPI.Components.Responses.InternalError) throws -> NSError {
        try NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: internalServerError.body.json.error])
    }

    static func nsError(undocumentedStatusCode: Int) -> NSError {
        NSError(
            domain: "",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "\(TKLocales.Errors.unknown) \(undocumentedStatusCode)"]
        )
    }
}

private func requireOnRampOk(
    _ output: SwapAPI.Operations.createExchange.Output
) throws -> SwapAPI.Components.Schemas.ExchangeResult {
    switch output {
    case let .ok(ok):
        return try ok.body.json
    case let .badRequest(error):
        throw try OnRampAPIClientError.nsError(badRequest: error)
    case let .internalServerError(error):
        throw try OnRampAPIClientError.nsError(internalServerError: error)
    case let .undocumented(statusCode: statusCode, _):
        throw OnRampAPIClientError.nsError(undocumentedStatusCode: statusCode)
    }
}

private func requireOnRampOk(
    _ output: SwapAPI.Operations.createP2PSession.Output
) throws -> SwapAPI.Components.Schemas.P2PSessionResult {
    switch output {
    case let .ok(ok):
        return try ok.body.json
    case let .badRequest(error):
        throw try OnRampAPIClientError.nsError(badRequest: error)
    case let .internalServerError(error):
        throw try OnRampAPIClientError.nsError(internalServerError: error)
    case let .undocumented(statusCode: statusCode, _):
        throw OnRampAPIClientError.nsError(undocumentedStatusCode: statusCode)
    }
}

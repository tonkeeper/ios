import SwapAPI
import TKLogging

protocol MultichainRampAPI {
    func getLayoutCards(flow: String, currency: String?) async throws -> OnRampLayoutCards
    func getOnrampChains(query: OnRampChainsQuery, walletId: String?) async throws -> OnRampChains
    func getOnrampConfiguration(query: OnRampConfigurationQuery, walletId: String?) async throws -> OnRampConfiguration
    func getOnrampAsset(assetId: String, fiat: String?, walletId: String?) async throws -> OnRampAssetDetail
    func onrampQuote(request: OnRampQuoteRequest, walletId: String?) async throws -> OnRampQuotesResult
    func createOnrampOrder(request: OnRampCreateOrderRequest, walletId: String?) async throws -> OnRampOrder
    func getOnrampOrder(orderId: String) async throws -> OnRampOrder

    func getOfframpConfiguration(query: OffRampConfigurationQuery) async throws -> OffRampConfiguration
    func getOfframpAsset(assetId: String) async throws -> OffRampAssetDetail
    func offrampQuote(request: OffRampQuoteRequest) async throws -> OffRampQuotesResult
    func createOfframpOrder(request: OffRampCreateOrderRequest) async throws -> OffRampOrder
    func getOfframpOrder(orderId: String) async throws -> OffRampOrder
}

final class MultichainRampAPIImplementation: MultichainRampAPI {
    private let client: SwapAPI.Client
    private let appInfoProvider: AppInfoProvider
    private let firebaseUserIdProvider: @Sendable () -> String?

    init(
        swapAPIClient: SwapAPI.Client,
        appInfoProvider: AppInfoProvider,
        firebaseUserIdProvider: @escaping @Sendable () -> String?
    ) {
        client = swapAPIClient
        self.appInfoProvider = appInfoProvider
        self.firebaseUserIdProvider = firebaseUserIdProvider
    }

    func getLayoutCards(flow: String, currency: String?) async throws -> OnRampLayoutCards {
        let query = await buildLayoutCardsQuery(flow: flow, currency: currency)
        let output = try await apiCall(await client.getExchangeLayoutCards(.init(query: query)))
        switch output {
        case let .ok(ok):
            return try OnRampLayoutCards(api: ok.body.json)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    func getOnrampChains(query: OnRampChainsQuery, walletId: String?) async throws -> OnRampChains {
        let apiQuery = await buildOnrampChainsQuery(query)
        let output = try await apiCall(await client.getOnrampChains(
            .init(query: apiQuery, headers: .init(X_hyphen_Wallet_hyphen_ID: walletId, F: firebaseUserIdProvider()))
        ))
        switch output {
        case let .ok(ok):
            return try OnRampChains(api: ok.body.json)
        case .notModified:
            throw MultichainRampAPIError.unknown(statusCode: 304)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    func getOnrampConfiguration(query: OnRampConfigurationQuery, walletId: String?) async throws -> OnRampConfiguration {
        let apiQuery = await buildOnrampConfigurationQuery(query)
        let output = try await apiCall(await client.getOnrampConfiguration(
            .init(query: apiQuery, headers: .init(X_hyphen_Wallet_hyphen_ID: walletId, F: firebaseUserIdProvider()))
        ))
        switch output {
        case let .ok(ok):
            return try OnRampConfiguration(api: ok.body.json)
        case .notModified:
            throw MultichainRampAPIError.unknown(statusCode: 304)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    func onrampQuote(request: OnRampQuoteRequest, walletId: String?) async throws -> OnRampQuotesResult {
        let query = await buildOnrampQuoteQuery()
        let output = try await apiCall(await client.onrampQuote(
            .init(
                query: query,
                headers: .init(X_hyphen_Wallet_hyphen_ID: walletId, F: firebaseUserIdProvider()),
                body: request.swapAPIRequestBody()
            )
        ))
        switch output {
        case let .ok(ok):
            return try OnRampQuotesResult(api: ok.body.json)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    func createOnrampOrder(request: OnRampCreateOrderRequest, walletId: String?) async throws -> OnRampOrder {
        let query = await buildCreateOnrampOrderQuery()
        let headers = SwapAPI.Operations.createOnrampOrder.Input.Headers(
            X_hyphen_Wallet_hyphen_ID: walletId,
            F: firebaseUserIdProvider(),
            Idempotency_hyphen_Key: request.idempotencyKey
        )
        let output = try await apiCall(await client.createOnrampOrder(
            .init(query: query, headers: headers, body: request.swapAPIRequestBody())
        ))
        return try mapOnrampOrder(output)
    }

    func getOnrampOrder(orderId: String) async throws -> OnRampOrder {
        let path = SwapAPI.Operations.getOnrampOrder.Input.Path(order_id: orderId)
        let output = try await apiCall(await client.getOnrampOrder(.init(path: path)))
        return try mapOnrampOrder(output)
    }

    func getOnrampAsset(assetId: String, fiat: String?, walletId: String?) async throws -> OnRampAssetDetail {
        let query = await buildOnrampAssetQuery(assetId: assetId, fiat: fiat)
        let output = try await apiCall(await client.getOnrampAsset(
            .init(query: query, headers: .init(X_hyphen_Wallet_hyphen_ID: walletId, F: firebaseUserIdProvider()))
        ))
        switch output {
        case let .ok(ok):
            return try OnRampAssetDetail(api: ok.body.json)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .notFound(response):
            throw Self.notFoundError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    func getOfframpConfiguration(query: OffRampConfigurationQuery) async throws -> OffRampConfiguration {
        let apiQuery = await buildOfframpConfigurationQuery(query)
        let output = try await apiCall(await client.getOfframpConfiguration(
            .init(query: apiQuery, headers: .init(F: firebaseUserIdProvider()))
        ))
        switch output {
        case let .ok(ok):
            return try OffRampConfiguration(api: ok.body.json)
        case .notModified:
            throw MultichainRampAPIError.unknown(statusCode: 304)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    func offrampQuote(request: OffRampQuoteRequest) async throws -> OffRampQuotesResult {
        let query = await buildOfframpQuoteQuery()
        let output = try await apiCall(await client.offrampQuote(
            .init(
                query: query,
                headers: .init(F: firebaseUserIdProvider()),
                body: request.swapAPIRequestBody()
            )
        ))
        switch output {
        case let .ok(ok):
            return try OffRampQuotesResult(api: ok.body.json)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    func createOfframpOrder(request: OffRampCreateOrderRequest) async throws -> OffRampOrder {
        let query = await buildCreateOfframpOrderQuery()
        let headers = SwapAPI.Operations.createOfframpOrder.Input.Headers(
            F: firebaseUserIdProvider(),
            Idempotency_hyphen_Key: request.idempotencyKey
        )
        let output = try await apiCall(await client.createOfframpOrder(
            .init(query: query, headers: headers, body: request.swapAPIRequestBody())
        ))
        return try mapOfframpOrder(output)
    }

    func getOfframpOrder(orderId: String) async throws -> OffRampOrder {
        let path = SwapAPI.Operations.getOfframpOrder.Input.Path(order_id: orderId)
        let output = try await apiCall(await client.getOfframpOrder(.init(path: path)))
        return try mapOfframpOrder(output)
    }

    func getOfframpAsset(assetId: String) async throws -> OffRampAssetDetail {
        let query = await buildOfframpAssetQuery(assetId: assetId)
        let output = try await apiCall(await client.getOfframpAsset(
            .init(query: query, headers: .init(F: firebaseUserIdProvider()))
        ))
        switch output {
        case let .ok(ok):
            return try OffRampAssetDetail(api: ok.body.json)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .notFound(response):
            throw Self.notFoundError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    private struct DeviceQueryContext {
        let deviceCountryCode: String?
        let storeCountryCode: String?
        let timezone: String
        let isVpnActive: Bool
        let build: String
        let platform: SwapAPI.Components.Schemas.Platform
    }

    private func makeDeviceQueryContext() async -> DeviceQueryContext {
        DeviceQueryContext(
            deviceCountryCode: appInfoProvider.deviceCountryCode,
            storeCountryCode: await appInfoProvider.storeCountryCode,
            timezone: appInfoProvider.timeZoneIdentifier,
            isVpnActive: appInfoProvider.isVPNActive,
            build: appInfoProvider.version,
            platform: SwapAPI.Components.Schemas.Platform(rawValue: appInfoProvider.platform) ?? .ios
        )
    }

    private func buildLayoutCardsQuery(
        flow: String,
        currency: String?
    ) async -> SwapAPI.Operations.getExchangeLayoutCards.Input.Query {
        let context = await makeDeviceQueryContext()
        let flowAPI = SwapAPI.Components.Schemas.ExchangeFlow(rawValue: flow) ?? .deposit
        return SwapAPI.Operations.getExchangeLayoutCards.Input.Query(
            flow: flowAPI,
            currency: currency,
            lang: appInfoProvider.language,
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            sim_country: nil,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            platform: context.platform
        )
    }

    private func buildOnrampQuoteQuery() async -> SwapAPI.Operations.onrampQuote.Input.Query {
        let context = await makeDeviceQueryContext()
        return SwapAPI.Operations.onrampQuote.Input.Query(
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            build: context.build,
            platform: context.platform
        )
    }

    private func buildCreateOnrampOrderQuery() async -> SwapAPI.Operations.createOnrampOrder.Input.Query {
        let context = await makeDeviceQueryContext()
        return SwapAPI.Operations.createOnrampOrder.Input.Query(
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            build: context.build,
            platform: context.platform
        )
    }

    private func buildOfframpQuoteQuery() async -> SwapAPI.Operations.offrampQuote.Input.Query {
        let context = await makeDeviceQueryContext()
        return SwapAPI.Operations.offrampQuote.Input.Query(
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            build: context.build,
            platform: context.platform
        )
    }

    private func buildCreateOfframpOrderQuery() async -> SwapAPI.Operations.createOfframpOrder.Input.Query {
        let context = await makeDeviceQueryContext()
        return SwapAPI.Operations.createOfframpOrder.Input.Query(
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            build: context.build,
            platform: context.platform
        )
    }

    private func buildOnrampChainsQuery(
        _ query: OnRampChainsQuery
    ) async -> SwapAPI.Operations.getOnrampChains.Input.Query {
        let context = await makeDeviceQueryContext()
        return SwapAPI.Operations.getOnrampChains.Input.Query(
            fiat: query.fiat,
            payment_method: query.paymentMethod.flatMap {
                SwapAPI.Components.Schemas.ExchangePaymentMethodType(rawValue: $0)
            },
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            build: context.build,
            platform: context.platform,
            lang: appInfoProvider.language
        )
    }

    private func buildOnrampConfigurationQuery(
        _ query: OnRampConfigurationQuery
    ) async -> SwapAPI.Operations.getOnrampConfiguration.Input.Query {
        let context = await makeDeviceQueryContext()
        return SwapAPI.Operations.getOnrampConfiguration.Input.Query(
            destination_chain: query.destinationChain,
            fiat: query.fiat,
            payment_method: query.paymentMethod.flatMap {
                SwapAPI.Components.Schemas.ExchangePaymentMethodType(rawValue: $0)
            },
            q: query.searchQuery,
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            build: context.build,
            platform: context.platform,
            lang: appInfoProvider.language,
            cursor: query.cursor,
            limit: query.limit
        )
    }

    private func buildOnrampAssetQuery(
        assetId: String,
        fiat: String?
    ) async -> SwapAPI.Operations.getOnrampAsset.Input.Query {
        let context = await makeDeviceQueryContext()
        return SwapAPI.Operations.getOnrampAsset.Input.Query(
            asset_id: assetId,
            fiat: fiat,
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            build: context.build,
            platform: context.platform,
            lang: appInfoProvider.language
        )
    }

    private func buildOfframpConfigurationQuery(
        _ query: OffRampConfigurationQuery
    ) async -> SwapAPI.Operations.getOfframpConfiguration.Input.Query {
        let context = await makeDeviceQueryContext()
        return SwapAPI.Operations.getOfframpConfiguration.Input.Query(
            source_chain: query.sourceChain,
            fiat: query.fiat,
            payout_method: query.payoutMethod.flatMap {
                SwapAPI.Components.Schemas.ExchangePaymentMethodType(rawValue: $0)
            },
            q: query.searchQuery,
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            build: context.build,
            platform: context.platform,
            lang: appInfoProvider.language,
            cursor: query.cursor,
            limit: query.limit
        )
    }

    private func buildOfframpAssetQuery(assetId: String) async -> SwapAPI.Operations.getOfframpAsset.Input.Query {
        let context = await makeDeviceQueryContext()
        return SwapAPI.Operations.getOfframpAsset.Input.Query(
            asset_id: assetId,
            device_country_code: context.deviceCountryCode,
            store_country_code: context.storeCountryCode,
            timezone: context.timezone,
            is_vpn_active: context.isVpnActive,
            build: context.build,
            platform: context.platform,
            lang: appInfoProvider.language
        )
    }

    private func mapOnrampOrder(
        _ output: SwapAPI.Operations.createOnrampOrder.Output
    ) throws -> OnRampOrder {
        switch output {
        case let .ok(ok):
            return try OnRampOrder(api: ok.body.json)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    private func mapOnrampOrder(
        _ output: SwapAPI.Operations.getOnrampOrder.Output
    ) throws -> OnRampOrder {
        switch output {
        case let .ok(ok):
            return try OnRampOrder(api: ok.body.json)
        case let .notFound(response):
            throw Self.notFoundError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    private func mapOfframpOrder(
        _ output: SwapAPI.Operations.createOfframpOrder.Output
    ) throws -> OffRampOrder {
        switch output {
        case let .ok(ok):
            return try OffRampOrder(api: ok.body.json)
        case let .badRequest(response):
            throw Self.badRequestError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    private func mapOfframpOrder(
        _ output: SwapAPI.Operations.getOfframpOrder.Output
    ) throws -> OffRampOrder {
        switch output {
        case let .ok(ok):
            return try OffRampOrder(api: ok.body.json)
        case let .notFound(response):
            throw Self.notFoundError(response)
        case let .internalServerError(response):
            throw Self.internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainRampAPIError.unknown(statusCode: statusCode)
        }
    }

    private static func badRequestError(_ response: SwapAPI.Components.Responses.BadRequest) -> MultichainRampAPIError {
        try errorPayload(response.body.json) {
            .badRequest(message: $0.error, code: $0.code, requestId: $0.request_id)
        }
    }

    private static func notFoundError(_ response: SwapAPI.Components.Responses.NotFound) -> MultichainRampAPIError {
        try errorPayload(response.body.json) {
            .notFound(message: $0.error, requestId: $0.request_id)
        }
    }

    private static func internalServerError(
        _ response: SwapAPI.Components.Responses.InternalError
    ) -> MultichainRampAPIError {
        try errorPayload(response.body.json) {
            .internalServerError(message: $0.error, requestId: $0.request_id)
        }
    }

    private static func errorPayload<Payload>(
        _ payload: @autoclosure () throws -> Payload,
        map: (Payload) -> MultichainRampAPIError
    ) -> MultichainRampAPIError {
        do {
            return try map(payload())
        } catch {
            Log.api.w("ramp error payload decoding failed", error: error)
            return .badResponse(diagnostic: MultichainAPIDiagnostic(error: error))
        }
    }

    /// Everything the generated client can throw — a cancelled task, a dead connection, a body it
    /// cannot decode — arrives here untyped, so it is mapped before it escapes to the UI as a
    /// runtime-library description.
    private func apiCall<T>(_ block: @autoclosure () async throws -> T) async throws -> T {
        do {
            return try await block()
        } catch {
            throw Task.isCancelled || error.isCancelledError
                ? MultichainRampAPIError.cancelled
                : MultichainRampAPIError.transportError(diagnostic: MultichainAPIDiagnostic(error: error))
        }
    }
}

public enum MultichainRampAPIError: Error, Sendable {
    case cancelled
    case badRequest(message: String, code: String?, requestId: String?)
    case notFound(message: String, requestId: String?)
    case internalServerError(message: String, requestId: String?)
    case badResponse(diagnostic: MultichainAPIDiagnostic)
    case transportError(diagnostic: MultichainAPIDiagnostic)
    case unknown(statusCode: Int)
}

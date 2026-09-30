import SwapAPI

protocol MultichainSwapAPI {
    func listCrossSwapAssets(query: MultichainSwapAssetsQuery) async throws(MultichainSwapAPIError) -> [MultichainSwapAsset]
    func getCrossSwapAsset(assetId: String) async throws(MultichainSwapAPIError) -> MultichainSwapAsset
    func getCrossSwapConfig(
        walletId: String,
        fromAssetId: String?,
        toAssetId: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapConfig
    func createCrossSwapQuote(
        request: MultichainSwapQuoteRequest,
        walletId: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote
    func prepareCrossSwapRoute(
        routeId: String,
        request: MultichainSwapPrepareRouteRequest?,
        walletId: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapPrepare
}

final class MultichainSwapAPIImplementation: MultichainSwapAPI {
    private let client: SwapAPI.Client
    private let firebaseUserIdProvider: @Sendable () -> String?
    private let isNewUser: @Sendable () -> Bool

    init(
        swapAPIClient: SwapAPI.Client,
        firebaseUserIdProvider: @escaping @Sendable () -> String?,
        isNewUser: @escaping @Sendable () -> Bool
    ) {
        client = swapAPIClient
        self.firebaseUserIdProvider = firebaseUserIdProvider
        self.isNewUser = isNewUser
    }

    func listCrossSwapAssets(query: MultichainSwapAssetsQuery) async throws(MultichainSwapAPIError) -> [MultichainSwapAsset] {
        let apiQuery = SwapAPI.Operations.listCrossSwapAssets.Input.Query(
            q: query.searchQuery,
            limit: query.limit,
            chain: query.chain
        )
        let output = try await apiCall(
            await client.listCrossSwapAssets(
                .init(query: apiQuery, headers: .init(F: firebaseUserIdProvider()))
            )
        )
        switch output {
        case let .ok(ok):
            return try decodeResponse(ok.body.json).assets.map { MultichainSwapAsset(api: $0) }
        case let .badRequest(response):
            throw try badRequestError(response)
        case let .internalServerError(response):
            throw try internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainSwapAPIError.unknown(statusCode: statusCode)
        }
    }

    func getCrossSwapAsset(assetId: String) async throws(MultichainSwapAPIError) -> MultichainSwapAsset {
        let query = SwapAPI.Operations.getCrossSwapAsset.Input.Query(asset_id: assetId)
        let output = try await apiCall(
            await client.getCrossSwapAsset(.init(query: query))
        )
        switch output {
        case let .ok(ok):
            return try MultichainSwapAsset(api: decodeResponse(ok.body.json))
        case let .badRequest(response):
            throw try badRequestError(response)
        case let .notFound(response):
            throw try notFoundError(response)
        case let .internalServerError(response):
            throw try internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainSwapAPIError.unknown(statusCode: statusCode)
        }
    }

    func getCrossSwapConfig(
        walletId: String,
        fromAssetId: String?,
        toAssetId: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapConfig {
        let path = SwapAPI.Operations.getCrossSwapConfig.Input.Path(wallet_id: walletId)
        let query = SwapAPI.Operations.getCrossSwapConfig.Input.Query(
            from_asset_id: fromAssetId,
            to_asset_id: toAssetId
        )
        let output = try await apiCall(
            await client.getCrossSwapConfig(.init(path: path, query: query))
        )
        switch output {
        case let .ok(ok):
            return try MultichainSwapConfig(api: decodeResponse(ok.body.json))
        case let .internalServerError(response):
            throw try internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainSwapAPIError.unknown(statusCode: statusCode)
        }
    }

    func createCrossSwapQuote(
        request: MultichainSwapQuoteRequest,
        walletId: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        let body = request.swapAPIRequestBody()
        let output = try await apiCall(
            await client.createCrossSwapQuote(
                .init(
                    query: .init(is_new: isNewUser()),
                    headers: .init(
                        X_hyphen_Wallet_hyphen_ID: walletId,
                        F: firebaseUserIdProvider()
                    ),
                    body: body
                )
            )
        )
        switch output {
        case let .ok(ok):
            return try MultichainSwapQuote(api: decodeResponse(ok.body.json))
        case let .badRequest(response):
            throw try badRequestError(response)
        case let .internalServerError(response):
            throw try internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainSwapAPIError.unknown(statusCode: statusCode)
        }
    }

    func prepareCrossSwapRoute(
        routeId: String,
        request: MultichainSwapPrepareRouteRequest?,
        walletId: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapPrepare {
        let path = SwapAPI.Operations.prepareCrossSwapRoute.Input.Path(route_id: routeId)
        let body = try request?.swapAPIRequestBody()
        let output = try await apiCall(
            await client.prepareCrossSwapRoute(
                .init(
                    path: path,
                    query: .init(is_new: isNewUser()),
                    headers: .init(
                        X_hyphen_Wallet_hyphen_ID: walletId,
                        F: firebaseUserIdProvider()
                    ),
                    body: body
                )
            )
        )
        switch output {
        case let .ok(ok):
            return try MultichainSwapPrepare(api: decodeResponse(ok.body.json))
        case let .badRequest(response):
            throw try badRequestError(response)
        case let .notFound(response):
            throw try notFoundError(response)
        case let .internalServerError(response):
            throw try internalServerError(response)
        case let .undocumented(statusCode, _):
            throw MultichainSwapAPIError.unknown(statusCode: statusCode)
        }
    }
}

private extension MultichainSwapAPIImplementation {
    func apiCall<T>(
        _ block: @autoclosure () async throws -> T
    ) async throws(MultichainSwapAPIError) -> T {
        do {
            return try await block()
        } catch {
            throw .transportError(diagnostic: MultichainAPIDiagnostic(error: error))
        }
    }

    func decodeResponse<T>(
        _ block: @autoclosure () throws -> T
    ) throws(MultichainSwapAPIError) -> T {
        do {
            return try block()
        } catch {
            throw .badResponse(diagnostic: MultichainAPIDiagnostic(error: error))
        }
    }

    func badRequestError(
        _ response: SwapAPI.Components.Responses.BadRequest
    ) throws(MultichainSwapAPIError) -> MultichainSwapAPIError {
        let payload = try decodeResponse(response.body.json)
        return .badRequest(message: payload.error, code: payload.code, requestId: payload.request_id)
    }

    func notFoundError(
        _ response: SwapAPI.Components.Responses.NotFound
    ) throws(MultichainSwapAPIError) -> MultichainSwapAPIError {
        let payload = try decodeResponse(response.body.json)
        return .notFound(message: payload.error, code: payload.code, requestId: payload.request_id)
    }

    func internalServerError(
        _ response: SwapAPI.Components.Responses.InternalError
    ) throws(MultichainSwapAPIError) -> MultichainSwapAPIError {
        let payload = try decodeResponse(response.body.json)
        return .internalServerError(message: payload.error, code: payload.code, requestId: payload.request_id)
    }
}

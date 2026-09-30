import Foundation
import TKTradingAPI

protocol TradingAPI {
    func getAssetChart(
        requestContext: TradingRequestContext,
        assetId: String,
        period: Period,
        currency: Currency
    ) async throws(TradingAPIError) -> [Coordinate]

    func getShelves(
        requestContext: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponse

    func getShelvesV2(
        requestContext: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponseV2

    func getAssetsCatalog(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query: String?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf: String?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse

    func getAssetsCatalogV2(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query: String?,
        sort: Components.Schemas.AssetsSort?,
        order: Components.Schemas.AssetsOrder?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf: String?,
        showPerps: Bool?,
        chain: String?,
        filter: Components.Schemas.AssetsFilter?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse

    func getAssets(
        requestContext: TradingRequestContext,
        ids: [String]
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse

    func getAssetsDetailsV2(
        requestContext: TradingRequestContext,
        assetId: String
    ) async throws(TradingAPIError) -> Components.Schemas.AssetDetailsResponse
}

extension TradingAPI {
    func getAssetsCatalogV2(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query: String?,
        sort: Components.Schemas.AssetsSort?,
        order: Components.Schemas.AssetsOrder?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf: String?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        try await getAssetsCatalogV2(
            requestContext: requestContext,
            tab: tab,
            query: query,
            sort: sort,
            order: order,
            cursor: cursor,
            pageSize: pageSize,
            sourceShelf: sourceShelf,
            showPerps: nil,
            chain: nil,
            filter: nil
        )
    }
}

struct TradingAPIImplementation {
    private let hostProvider: APIHostProvider
    private let urlSession: URLSession

    init(
        hostProvider: APIHostProvider,
        urlSession: URLSession
    ) {
        self.hostProvider = hostProvider
        self.urlSession = urlSession
    }
}

// MARK: - Convenience

private extension TradingAPIImplementation {
    func apiClient() async throws(TradingAPIError) -> Client {
        do {
            return try await Client(
                hostProvider: hostProvider,
                urlSession: urlSession
            )
        } catch {
            switch error {
            case .badHost:
                throw .badUrl(underlying: error)
            }
        }
    }

    func apiCall<T>(
        _ block: @autoclosure () async throws -> T
    ) async throws(TradingAPIError) -> T {
        do {
            return try await block()
        } catch {
            throw .transportError(underlying: error)
        }
    }

    func decodeResponse<T>(
        _ block: @autoclosure () throws -> T
    ) throws(TradingAPIError) -> T {
        do {
            return try block()
        } catch {
            throw .badResponse(underlying: error)
        }
    }

    func coordinates(
        from chartPoints: Components.Schemas.ChartPoints
    ) -> [Coordinate] {
        chartPoints
            .compactMap { item -> Coordinate? in
                guard item.count == 2 else {
                    return nil
                }
                return Coordinate(x: item[0], y: item[1])
            }
            .sorted { $0.x < $1.x }
    }
}

// MARK: - API

extension TradingAPIImplementation: TradingAPI {
    func getAssetChart(
        requestContext: TradingRequestContext,
        assetId: String,
        period: Period,
        currency: Currency
    ) async throws(TradingAPIError) -> [Coordinate] {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getAssetChartsV2(
                path: .init(assetId: assetId),
                query: .init(
                    currency: currency.code.lowercased(),
                    store_country_code: requestContext.storeCountryCode,
                    sim_country: requestContext.simCountryCode,
                    device_country_code: requestContext.deviceCountryCode,
                    timezone: requestContext.timezoneIdentifier,
                    is_vpn_active: requestContext.isVPNActive,
                    start_date: Int64(period.startDate.timeIntervalSince1970),
                    end_date: Int64(period.endDate.timeIntervalSince1970)
                ),
                headers: .init(
                    User_hyphen_Agent: requestContext.userAgent,
                    X_hyphen_Lang: requestContext.language
                )
            )
        )

        switch response {
        case let .ok(ok):
            return try coordinates(from: decodeResponse(ok.body.json))
        case let .badRequest(badRequest):
            throw try .badStatus(
                message: decodeResponse(badRequest.body.json).message
            )
        case let .unauthorized(unauthorized):
            throw try .badStatus(
                message: decodeResponse(unauthorized.body.json).message
            )
        case .notFound:
            throw .badStatus(
                message: "Asset chart not found"
            )
        case let .tooManyRequests(tooManyRequests):
            throw try .badStatus(
                message: decodeResponse(tooManyRequests.body.json).message
            )
        case let .internalServerError(internalServerError):
            throw try .badStatus(
                message: decodeResponse(internalServerError.body.json).message
            )
        case let .undocumented(statusCode, _):
            throw .badStatus(
                message: "undocumented status code: \(statusCode)"
            )
        }
    }

    func getShelves(
        requestContext: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponse {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getShelvesConfig(
                query: .init(
                    currency: requestContext.currency.code.lowercased(),
                    store_country_code: requestContext.storeCountryCode,
                    sim_country: requestContext.simCountryCode,
                    device_country_code: requestContext.deviceCountryCode,
                    timezone: requestContext.timezoneIdentifier,
                    is_vpn_active: requestContext.isVPNActive
                ),
                headers: .init(
                    User_hyphen_Agent: requestContext.userAgent,
                    X_hyphen_Lang: requestContext.language
                )
            )
        )

        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .badRequest(badRequest):
            throw try .badStatus(
                message: decodeResponse(badRequest.body.json).message
            )
        case let .unauthorized(unauthorized):
            throw try .badStatus(
                message: decodeResponse(unauthorized.body.json).message
            )
        case let .tooManyRequests(tooManyRequests):
            throw try .badStatus(
                message: decodeResponse(tooManyRequests.body.json).message
            )
        case let .internalServerError(internalServerError):
            throw try .badStatus(
                message: decodeResponse(internalServerError.body.json).message
            )
        case let .undocumented(statusCode, _):
            throw .badStatus(
                message: "undocumented status code: \(statusCode)"
            )
        }
    }

    func getShelvesV2(
        requestContext: TradingRequestContext
    ) async throws(TradingAPIError) -> Components.Schemas.ShelvesConfigResponseV2 {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getShelvesConfigV2(
                query: .init(
                    currency: requestContext.currency.code.lowercased(),
                    store_country_code: requestContext.storeCountryCode,
                    sim_country: requestContext.simCountryCode,
                    device_country_code: requestContext.deviceCountryCode,
                    timezone: requestContext.timezoneIdentifier,
                    is_vpn_active: requestContext.isVPNActive
                ),
                headers: .init(
                    User_hyphen_Agent: requestContext.userAgent,
                    X_hyphen_Lang: requestContext.language
                )
            )
        )

        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .badRequest(badRequest):
            throw try .badStatus(
                message: decodeResponse(badRequest.body.json).message
            )
        case let .unauthorized(unauthorized):
            throw try .badStatus(
                message: decodeResponse(unauthorized.body.json).message
            )
        case let .tooManyRequests(tooManyRequests):
            throw try .badStatus(
                message: decodeResponse(tooManyRequests.body.json).message
            )
        case let .internalServerError(internalServerError):
            throw try .badStatus(
                message: decodeResponse(internalServerError.body.json).message
            )
        case let .undocumented(statusCode, _):
            throw .badStatus(
                message: "undocumented status code: \(statusCode)"
            )
        }
    }

    func getAssetsCatalog(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query: String?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf: String?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getAssetsCatalog(
                query: .init(
                    currency: requestContext.currency.code.lowercased(),
                    store_country_code: requestContext.storeCountryCode,
                    sim_country: requestContext.simCountryCode,
                    device_country_code: requestContext.deviceCountryCode,
                    timezone: requestContext.timezoneIdentifier,
                    is_vpn_active: requestContext.isVPNActive,
                    tab: tab,
                    q: query,
                    source_shelf: sourceShelf,
                    cursor: cursor,
                    page_size: pageSize
                ),
                headers: .init(
                    User_hyphen_Agent: requestContext.userAgent,
                    X_hyphen_Lang: requestContext.language
                )
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .badRequest(badRequest):
            throw try .badStatus(
                message: decodeResponse(badRequest.body.json).message
            )
        case let .unauthorized(unauthorized):
            throw try .badStatus(
                message: decodeResponse(unauthorized.body.json).message
            )
        case let .notFound(notFound):
            throw try .badStatus(
                message: decodeResponse(notFound.body.json).message
            )
        case let .tooManyRequests(tooManyRequests):
            throw try .badStatus(
                message: decodeResponse(tooManyRequests.body.json).message
            )
        case let .internalServerError(internalServerError):
            throw try .badStatus(
                message: decodeResponse(internalServerError.body.json).message
            )
        case let .undocumented(statusCode, _):
            throw .badStatus(
                message: "undocumented status code: \(statusCode)"
            )
        }
    }

    func getAssetsCatalogV2(
        requestContext: TradingRequestContext,
        tab: Components.Schemas.AssetsTab,
        query: String?,
        sort: Components.Schemas.AssetsSort?,
        order: Components.Schemas.AssetsOrder?,
        cursor: String?,
        pageSize: Int?,
        sourceShelf: String?,
        showPerps: Bool?,
        chain: String?,
        filter: Components.Schemas.AssetsFilter?
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getAssetsCatalogV2(
                query: .init(
                    currency: requestContext.currency.code.lowercased(),
                    store_country_code: requestContext.storeCountryCode,
                    sim_country: requestContext.simCountryCode,
                    device_country_code: requestContext.deviceCountryCode,
                    timezone: requestContext.timezoneIdentifier,
                    is_vpn_active: requestContext.isVPNActive,
                    tab: tab,
                    q: query,
                    show_perps: showPerps,
                    chain: chain,
                    sort: sort,
                    order: order,
                    filter: filter,
                    source_shelf: sourceShelf,
                    cursor: cursor,
                    page_size: pageSize
                ),
                headers: .init(
                    User_hyphen_Agent: requestContext.userAgent,
                    X_hyphen_Lang: requestContext.language
                )
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .badRequest(badRequest):
            throw try .badStatus(
                message: decodeResponse(badRequest.body.json).message
            )
        case let .unauthorized(unauthorized):
            throw try .badStatus(
                message: decodeResponse(unauthorized.body.json).message
            )
        case let .notFound(notFound):
            throw try .badStatus(
                message: decodeResponse(notFound.body.json).message
            )
        case let .tooManyRequests(tooManyRequests):
            throw try .badStatus(
                message: decodeResponse(tooManyRequests.body.json).message
            )
        case let .internalServerError(internalServerError):
            throw try .badStatus(
                message: decodeResponse(internalServerError.body.json).message
            )
        case let .undocumented(statusCode, _):
            throw .badStatus(
                message: "undocumented status code: \(statusCode)"
            )
        }
    }

    func getAssets(
        requestContext: TradingRequestContext,
        ids: [String]
    ) async throws(TradingAPIError) -> Components.Schemas.AssetsCatalogResponse {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getAssetsCatalogV2(
                query: .init(
                    currency: requestContext.currency.code.lowercased(),
                    store_country_code: requestContext.storeCountryCode,
                    sim_country: requestContext.simCountryCode,
                    device_country_code: requestContext.deviceCountryCode,
                    timezone: requestContext.timezoneIdentifier,
                    is_vpn_active: requestContext.isVPNActive,
                    ids: ids
                ),
                headers: .init(
                    User_hyphen_Agent: requestContext.userAgent,
                    X_hyphen_Lang: requestContext.language
                )
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .badRequest(badRequest):
            throw try .badStatus(
                message: decodeResponse(badRequest.body.json).message
            )
        case let .unauthorized(unauthorized):
            throw try .badStatus(
                message: decodeResponse(unauthorized.body.json).message
            )
        case let .notFound(notFound):
            throw try .badStatus(
                message: decodeResponse(notFound.body.json).message
            )
        case let .tooManyRequests(tooManyRequests):
            throw try .badStatus(
                message: decodeResponse(tooManyRequests.body.json).message
            )
        case let .internalServerError(internalServerError):
            throw try .badStatus(
                message: decodeResponse(internalServerError.body.json).message
            )
        case let .undocumented(statusCode, _):
            throw .badStatus(
                message: "undocumented status code: \(statusCode)"
            )
        }
    }

    func getAssetsDetailsV2(
        requestContext: TradingRequestContext,
        assetId: String
    ) async throws(TradingAPIError) -> Components.Schemas.AssetDetailsResponse {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.getAssetDetailsV2(
                path: .init(assetId: assetId),
                query: .init(
                    currency: requestContext.currency.code.lowercased(),
                    store_country_code: requestContext.storeCountryCode,
                    sim_country: requestContext.simCountryCode,
                    device_country_code: requestContext.deviceCountryCode,
                    timezone: requestContext.timezoneIdentifier,
                    is_vpn_active: requestContext.isVPNActive
                ),
                headers: .init(
                    User_hyphen_Agent: requestContext.userAgent,
                    X_hyphen_Lang: requestContext.language
                )
            )
        )
        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json)
        case let .badRequest(badRequest):
            throw try .badStatus(
                message: decodeResponse(badRequest.body.json).message
            )
        case let .unauthorized(unauthorized):
            throw try .badStatus(
                message: decodeResponse(unauthorized.body.json).message
            )
        case let .tooManyRequests(tooManyRequests):
            throw try .badStatus(
                message: decodeResponse(tooManyRequests.body.json).message
            )
        case let .internalServerError(internalServerError):
            throw try .badStatus(
                message: decodeResponse(internalServerError.body.json).message
            )
        case .notFound:
            throw .notFound
        case let .undocumented(statusCode, _):
            throw .badStatus(
                message: "undocumented status code: \(statusCode)"
            )
        }
    }
}

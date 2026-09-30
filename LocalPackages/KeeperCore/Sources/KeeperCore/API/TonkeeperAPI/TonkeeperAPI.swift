import Foundation
import TKTonkeeperAPI

public enum TonkeeperAPIError: Swift.Error {
    case cancelled
    case incorrectUrl
    case badStatus(
        statusCode: Int,
        message: String
    )
    case badResponse(
        underlying: Swift.Error?
    )
    case transportError(
        underlying: Swift.Error?
    )
}

extension TonkeeperAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            "cancelled"
        case .incorrectUrl:
            "incorrect url"
        case let .badStatus(statusCode, message):
            "bad status \(statusCode), message: \(message)"
        case let .badResponse(error):
            "bad response, error: \(error?.localizedDescription ?? "nil")"
        case let .transportError(error):
            "network error, error: \(error?.localizedDescription ?? "nil")"
        }
    }
}

public protocol TonkeeperAPI {
    func loadFiatMethods(countryCode: String?, walletId: String?) async throws -> FiatMethods
    func loadPopularApps(lang: String, walletId: String?) async throws(TonkeeperAPIError) -> PopularAppsResponseData
    func loadBanners(walletId: String?) async throws -> [HomeBanner]
    func loadNotifications(walletId: String?) async throws(TonkeeperAPIError) -> [InternalNotification]
    func loadStory(storyId: String, walletId: String?) async throws -> Story
    func loadStories(storyIds: [String], walletId: String?) async throws(TonkeeperAPIError) -> [Story]
    func getIP() async throws -> String
    func getEthenaStakingDetails(address: String, walletId: String?) async throws -> EthenaStakingResponse
}

struct TonkeeperAPIImplementation: TonkeeperAPI {
    typealias Components = TKTonkeeperAPI.Components

    private let urlSession: URLSession
    private let hostProvider: APIHostProvider
    private let appInfoProvider: AppInfoProvider
    private let isNewUser: @Sendable () -> Bool

    init(
        urlSession: URLSession,
        hostProvider: APIHostProvider,
        appInfoProvider: AppInfoProvider,
        isNewUser: @escaping @Sendable () -> Bool
    ) {
        self.urlSession = urlSession
        self.hostProvider = hostProvider
        self.appInfoProvider = appInfoProvider
        self.isNewUser = isNewUser
    }

    func loadFiatMethods(countryCode: String?, walletId: String?) async throws(TonkeeperAPIError) -> FiatMethods {
        let client = try await apiClient()
        let context = await requestContext()
        let response = try await apiCall(
            await client.getFiatMethods(
                query: .init(
                    chainName: .mainnet,
                    lang: context.language,
                    countryCode: countryCode,
                    build: context.build,
                    platform: context.platform,
                    store_country_code: context.storeCountryCode,
                    device_country_code: context.deviceCountryCode,
                    sim_country: nil,
                    timezone: context.timezone,
                    is_vpn_active: context.isVPNActive,
                    wallet_id: walletId
                )
            )
        )

        switch response {
        case let .ok(ok):
            let entity: FiatMethodsResponse = try legacyModel(
                from: decodeResponse(ok.body.json)
            )
            return entity.data
        case let .badRequest(badRequest):
            throw try badStatus(
                statusCode: 400,
                response: badRequest
            )
        case let .internalServerError(internalServerError):
            throw try badStatus(
                statusCode: 500,
                response: internalServerError
            )
        case let .undocumented(statusCode, _):
            throw undocumentedStatus(statusCode)
        }
    }

    func loadPopularApps(lang: String, walletId: String?) async throws(TonkeeperAPIError) -> PopularAppsResponseData {
        let client = try await apiClient()
        let context = await requestContext(language: lang)
        let response = try await apiCall(
            await client.getPopularApps(
                query: .init(
                    lang: context.language,
                    build: context.build,
                    platform: context.platform,
                    with_ads: nil,
                    store_country_code: context.storeCountryCode,
                    device_country_code: context.deviceCountryCode,
                    sim_country: nil,
                    timezone: context.timezone,
                    is_vpn_active: context.isVPNActive,
                    wallet_id: walletId
                )
            )
        )

        switch response {
        case let .ok(ok):
            let payload = try decodeResponse(ok.body.json)
            return PopularAppsResponseData(payload.data)
        case let .badRequest(badRequest):
            throw try badStatus(
                statusCode: 400,
                response: badRequest
            )
        case let .internalServerError(internalServerError):
            throw try badStatus(
                statusCode: 500,
                response: internalServerError
            )
        case let .undocumented(statusCode, _):
            throw undocumentedStatus(statusCode)
        }
    }

    func loadBanners(walletId: String?) async throws -> [HomeBanner] {
        let features = enabledFeatures()
        let client = try await apiClient()
        let context = await requestContext()
        let response = try await apiCall(
            await client.getBanners(
                query: .init(
                    lang: context.language,
                    build: context.build,
                    platform: context.platform,
                    store_country_code: context.storeCountryCode,
                    device_country_code: context.deviceCountryCode,
                    sim_country: nil,
                    timezone: context.timezone,
                    is_vpn_active: context.isVPNActive,
                    wallet_id: walletId,
                    features: features.joined(separator: ","),
                    is_new: isNewUser()
                )
            )
        )

        switch response {
        case let .ok(ok):
            let entity: HomeBannersResponse = try legacyModel(
                from: decodeResponse(ok.body.json)
            )
            return entity.banners
        case let .badRequest(badRequest):
            throw try badStatus(
                statusCode: 400,
                response: badRequest
            )
        case let .internalServerError(internalServerError):
            throw try badStatus(
                statusCode: 500,
                response: internalServerError
            )
        case let .undocumented(statusCode, _):
            throw undocumentedStatus(statusCode)
        }
    }

    func loadNotifications(walletId: String?) async throws(TonkeeperAPIError) -> [InternalNotification] {
        let client = try await apiClient()
        let context = await requestContext()
        let response = try await apiCall(
            await client.getNotifications(
                query: .init(
                    platform: context.platform,
                    build: context.build,
                    lang: context.language,
                    wallet_id: walletId
                )
            )
        )

        switch response {
        case let .ok(ok):
            let entity: InternalNotificationResponse = try legacyModel(
                from: decodeResponse(ok.body.json)
            )
            return entity.notifications
        case let .badRequest(badRequest):
            throw try badStatus(
                statusCode: 400,
                response: badRequest
            )
        case let .internalServerError(internalServerError):
            throw try badStatus(
                statusCode: 500,
                response: internalServerError
            )
        case let .undocumented(statusCode, _):
            throw undocumentedStatus(statusCode)
        }
    }

    func loadStory(storyId: String, walletId: String?) async throws(TonkeeperAPIError) -> Story {
        let features = enabledFeatures()
        let client = try await apiClient()
        let context = await requestContext()
        let response = try await apiCall(
            await client.getStories(
                path: .init(story_id: storyId),
                query: .init(
                    lang: context.language,
                    build: context.build,
                    platform: context.platform,
                    store_country_code: context.storeCountryCode,
                    device_country_code: context.deviceCountryCode,
                    sim_country: nil,
                    timezone: context.timezone,
                    is_vpn_active: context.isVPNActive,
                    wallet_id: walletId,
                    features: features.joined(separator: ","),
                    is_new: isNewUser()
                )
            )
        )

        switch response {
        case let .ok(ok):
            return try legacyModel(
                from: decodeResponse(ok.body.json),
                as: Story.self
            )
        case let .badRequest(badRequest):
            throw try badStatus(
                statusCode: 400,
                response: badRequest
            )
        case let .notFound(notFound):
            throw try badStatus(
                statusCode: 404,
                response: notFound
            )
        case let .internalServerError(internalServerError):
            throw try badStatus(
                statusCode: 500,
                response: internalServerError
            )
        case let .undocumented(statusCode, _):
            throw undocumentedStatus(statusCode)
        }
    }

    func loadStories(storyIds: [String], walletId: String?) async throws(TonkeeperAPIError) -> [Story] {
        let features = enabledFeatures()
        let client = try await apiClient()
        let context = await requestContext()
        let response = try await apiCall(
            await client.getStoriesBatch(
                query: .init(
                    ids: storyIds.joined(separator: ","),
                    lang: context.language,
                    build: context.build,
                    platform: context.platform,
                    store_country_code: context.storeCountryCode,
                    device_country_code: context.deviceCountryCode,
                    sim_country: nil,
                    timezone: context.timezone,
                    is_vpn_active: context.isVPNActive,
                    wallet_id: walletId,
                    features: features.joined(separator: ","),
                    is_new: isNewUser()
                )
            )
        )

        switch response {
        case let .ok(ok):
            let entity: StoriesResponse = try legacyModel(
                from: decodeResponse(ok.body.json)
            )
            return entity.stories
        case let .badRequest(badRequest):
            throw try badStatus(
                statusCode: 400,
                response: badRequest
            )
        case let .notFound(notFound):
            throw try badStatus(
                statusCode: 404,
                response: notFound
            )
        case let .internalServerError(internalServerError):
            throw try badStatus(
                statusCode: 500,
                response: internalServerError
            )
        case let .undocumented(statusCode, _):
            throw undocumentedStatus(statusCode)
        }
    }

    func getIP() async throws(TonkeeperAPIError) -> String {
        let client = try await apiClient()
        let response = try await apiCall(
            await client.myIp()
        )

        switch response {
        case let .ok(ok):
            return try decodeResponse(ok.body.json).ip
        case let .badRequest(badRequest):
            throw try badStatus(
                statusCode: 400,
                response: badRequest
            )
        case let .notFound(notFound):
            throw try badStatus(
                statusCode: 404,
                response: notFound
            )
        case let .internalServerError(internalServerError):
            throw try badStatus(
                statusCode: 500,
                response: internalServerError
            )
        case let .undocumented(statusCode, _):
            throw undocumentedStatus(statusCode)
        }
    }

    func getEthenaStakingDetails(address: String, walletId: String?) async throws(TonkeeperAPIError) -> EthenaStakingResponse {
        let client = try await apiClient()
        let context = await requestContext()
        let response = try await apiCall(
            await client.getStakingEthenaMethods(
                query: .init(
                    address: address,
                    lang: context.language,
                    wallet_id: walletId
                )
            )
        )

        switch response {
        case let .ok(ok):
            return try legacyModel(
                from: decodeResponse(ok.body.json),
                as: EthenaStakingResponse.self
            )
        case let .badRequest(badRequest):
            throw try badStatus(
                statusCode: 400,
                response: badRequest
            )
        case let .notFound(notFound):
            throw try badStatus(
                statusCode: 404,
                response: notFound
            )
        case let .internalServerError(internalServerError):
            throw try badStatus(
                statusCode: 500,
                response: internalServerError
            )
        case let .undocumented(statusCode, _):
            throw undocumentedStatus(statusCode)
        }
    }
}

// MARK: - Convenience

private extension TonkeeperAPIImplementation {
    struct RequestContext {
        let language: String
        let build: String
        let platform: Components.Schemas.Platform?
        let storeCountryCode: String?
        let deviceCountryCode: String?
        let timezone: String
        let isVPNActive: Bool?
    }

    func enabledFeatures() -> [String] {
        ["multichain"]
    }

    func apiClient() async throws(TonkeeperAPIError) -> TKTonkeeperAPI.Client {
        do {
            return try await TKTonkeeperAPI.Client(
                hostProvider: hostProvider,
                urlSession: urlSession
            )
        } catch {
            if error.isCancelledError {
                throw .cancelled
            }
            throw .incorrectUrl
        }
    }

    func requestContext(language: String? = nil) async -> RequestContext {
        RequestContext(
            language: language ?? appInfoProvider.language,
            build: appInfoProvider.version,
            platform: Components.Schemas.Platform(rawValue: appInfoProvider.platform),
            storeCountryCode: await appInfoProvider.storeCountryCode,
            deviceCountryCode: appInfoProvider.deviceCountryCode,
            timezone: appInfoProvider.timeZoneIdentifier,
            isVPNActive: appInfoProvider.isVPNActive ? true : nil
        )
    }

    func apiCall<T>(
        _ block: @autoclosure () async throws -> T
    ) async throws(TonkeeperAPIError) -> T {
        do {
            return try await block()
        } catch {
            if error.isCancelledError {
                throw .cancelled
            }
            throw .transportError(underlying: error)
        }
    }

    func decodeResponse<T>(
        _ block: @autoclosure () throws -> T
    ) throws(TonkeeperAPIError) -> T {
        do {
            return try block()
        } catch {
            throw TonkeeperAPIError.badResponse(underlying: error)
        }
    }

    func legacyModel<Payload: Encodable, Model: Decodable>(
        from payload: Payload,
        as _: Model.Type = Model.self
    ) throws(TonkeeperAPIError) -> Model {
        try decodeResponse(
            JSONDecoder().decode(
                Model.self,
                from: JSONEncoder().encode(payload)
            )
        )
    }

    func badStatus(
        statusCode: Int,
        response: Components.Responses.BadRequest
    ) throws(TonkeeperAPIError) -> TonkeeperAPIError {
        try .badStatus(
            statusCode: statusCode,
            message: decodeResponse(response.body.json).error
        )
    }

    func badStatus(
        statusCode: Int,
        response: Components.Responses.NotFound
    ) throws(TonkeeperAPIError) -> TonkeeperAPIError {
        try .badStatus(
            statusCode: statusCode,
            message: decodeResponse(response.body.json).error
        )
    }

    func badStatus(
        statusCode: Int,
        response: Components.Responses.InternalError
    ) throws(TonkeeperAPIError) -> TonkeeperAPIError {
        try .badStatus(
            statusCode: statusCode,
            message: decodeResponse(response.body.json).error
        )
    }

    func undocumentedStatus(_ statusCode: Int) -> TonkeeperAPIError {
        .badStatus(
            statusCode: statusCode,
            message: "undocumented status code: \(statusCode)"
        )
    }
}

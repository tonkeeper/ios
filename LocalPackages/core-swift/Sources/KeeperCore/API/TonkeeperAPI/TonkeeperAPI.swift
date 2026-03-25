import Foundation
import TKLogging

enum TonkeeperAPIError: Swift.Error {
    case incorrectUrl
}

public protocol TonkeeperAPI {
    func loadFiatMethods(countryCode: String?) async throws -> FiatMethods
    func loadPopularApps(lang: String) async throws -> PopularAppsResponseData
    func loadNotifications() async throws -> [InternalNotification]
    func loadStory(storyId: String) async throws -> Story
    func loadStories(storyIds: [String]) async throws -> [Story]
    func getIP() async throws -> String
    func getEthenaStakingDetails(address: String) async throws -> EthenaStakingResponse
}

struct TonkeeperAPIImplementation: TonkeeperAPI {
    private let urlSession: URLSession
    private let defaultHost: URL
    private let configHost: () -> URL?
    private let urlComponentsBuilder: AppInfoURLComponentsBuilder

    var host: URL {
        configHost() ?? defaultHost
    }

    init(
        urlSession: URLSession,
        defaultHost: URL,
        configHost: @escaping () -> URL?,
        appInfoProvider: AppInfoProvider
    ) {
        self.urlSession = urlSession
        self.defaultHost = defaultHost
        self.configHost = configHost
        self.urlComponentsBuilder = AppInfoURLComponentsBuilder(appInfoProvider: appInfoProvider)
    }

    func loadFiatMethods(countryCode: String?) async throws -> FiatMethods {
        let url = host.appendingPathComponent("/fiat/methods")
        let components = try await urlComponentsBuilder.buildURLComponents(for: url, additionalQueryItems: [
            .init(name: "chainName", value: "mainnet"),
        ])

        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        let entity = try JSONDecoder().decode(FiatMethodsResponse.self, from: data)
        return entity.data
    }

    func loadPopularApps(lang: String) async throws -> PopularAppsResponseData {
        let url = host.appendingPathComponent("/apps/popular")
        let components = try await urlComponentsBuilder.buildURLComponents(for: url)
        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        let entity = try JSONDecoder().decode(PopularAppsResponse.self, from: data)
        return entity.data
    }

    func loadNotifications() async throws -> [InternalNotification] {
        let url = host.appendingPathComponent("/notifications")
        let components = try await urlComponentsBuilder.buildURLComponents(for: url)
        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        do {
            let response = try JSONDecoder().decode(InternalNotificationResponse.self, from: data)
            return response.notifications
        } catch {
            throw error
        }
    }

    func loadStory(storyId: String) async throws -> Story {
        let url = host.appendingPathComponent("/stories").appendingPathComponent("/" + storyId)
        let components = try await urlComponentsBuilder.buildURLComponents(for: url)
        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        do {
            return try JSONDecoder().decode(Story.self, from: data)
        } catch {
            throw error
        }
    }

    func loadStories(storyIds: [String]) async throws -> [Story] {
        let url = host.appendingPathComponent("/stories")
        let components = try await urlComponentsBuilder.buildURLComponents(for: url, additionalQueryItems: [
            .init(name: "ids", value: storyIds.joined(separator: ",")),
        ])
        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        do {
            let response = try JSONDecoder().decode(StoriesResponse.self, from: data)
            return response.stories
        } catch {
            Log.w("error loading stories: \(error)")
            throw error
        }
    }

    func getIP() async throws -> String {
        struct Response: Decodable {
            let ip: String
            let country: String
        }

        let url = host.appendingPathComponent("/my/ip")
        let components = try await urlComponentsBuilder.buildURLComponents(for: url)
        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        let entity = try JSONDecoder().decode(Response.self, from: data)
        return entity.ip
    }

    func getEthenaStakingDetails(address: String) async throws -> EthenaStakingResponse {
        let url = host.appendingPathComponent("/staking/ethena")
        let components = try await urlComponentsBuilder.buildURLComponents(for: url, additionalQueryItems: [
            .init(name: "address", value: address),
        ])
        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        do {
            return try JSONDecoder().decode(EthenaStakingResponse.self, from: data)
        } catch {
            throw error
        }
    }
}

import Foundation

protocol RemoteConfigurationAPI {
    func loadConfiguration() async throws -> RemoteConfigurations
}

final class RemoteConfigurationAPIImplementation: RemoteConfigurationAPI {
    private let urlSession: URLSession
    private let urlComponentsBuilder: AppInfoURLComponentsBuilder
    private let bootHost: URL
    private let blockHost: URL

    init(
        urlSession: URLSession,
        bootHost: URL,
        blockHost: URL,
        appInfoProvider: AppInfoProvider
    ) {
        self.urlSession = urlSession
        self.bootHost = bootHost
        self.blockHost = blockHost
        self.urlComponentsBuilder = AppInfoURLComponentsBuilder(appInfoProvider: appInfoProvider)
    }

    func loadConfiguration() async throws -> RemoteConfigurations {
        do {
            return try await loadConfiguration(host: bootHost)
        } catch {
            return try await loadConfiguration(host: blockHost)
        }
    }

    private func loadConfiguration(host: URL) async throws -> RemoteConfigurations {
        let url = host.appendingPathComponent("/keys/all")
        let components = try await urlComponentsBuilder.buildURLComponents(for: url)
        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        return try JSONDecoder().decode(RemoteConfigurations.self, from: data)
    }
}

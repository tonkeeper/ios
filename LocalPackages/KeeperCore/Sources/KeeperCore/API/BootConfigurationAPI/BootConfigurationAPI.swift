import Foundation

struct BootConfigurationRequestContext: Sendable {
    let features: [String]
    let walletID: String?
}

protocol BootConfigurationAPI {
    func loadConfigurations() async throws -> BootConfigurations
}

final class BootConfigurationAPIImplementation: BootConfigurationAPI {
    private let urlSession: URLSession
    private let urlComponentsBuilder: AppInfoURLComponentsBuilder
    private let bootHost: URL
    private let blockHost: URL
    private let requestContextProvider: @Sendable () -> BootConfigurationRequestContext

    init(
        urlSession: URLSession,
        bootHost: URL,
        blockHost: URL,
        appInfoProvider: AppInfoProvider,
        requestContextProvider: @escaping @Sendable () -> BootConfigurationRequestContext
    ) {
        self.urlSession = urlSession
        self.bootHost = bootHost
        self.blockHost = blockHost
        self.urlComponentsBuilder = AppInfoURLComponentsBuilder(appInfoProvider: appInfoProvider)
        self.requestContextProvider = requestContextProvider
    }

    func loadConfigurations() async throws -> BootConfigurations {
        do {
            return try await loadConfiguration(host: bootHost)
        } catch {
            return try await loadConfiguration(host: blockHost)
        }
    }

    private func loadConfiguration(host: URL) async throws -> BootConfigurations {
        let url = host.appendingPathComponent("/keys/all")
        let requestContext = requestContextProvider()
        var queryItems = requestContext.walletID.map {
            [URLQueryItem(name: "wallet_id", value: $0)]
        } ?? []
        if !requestContext.features.isEmpty {
            queryItems.append(URLQueryItem(name: "features", value: requestContext.features.joined(separator: ",")))
        }
        let components = try await urlComponentsBuilder.buildURLComponents(
            for: url,
            additionalQueryItems: queryItems
        )
        guard let url = components.url else { throw TonkeeperAPIError.incorrectUrl }
        let (data, _) = try await urlSession.data(from: url)
        return try JSONDecoder().decode(BootConfigurations.self, from: data)
    }
}

import Foundation

protocol RemoteConfigurationService {
    func getConfiguration() throws -> RemoteConfigurations
    func loadConfiguration() async throws -> RemoteConfigurations
}

final class RemoteConfigurationServiceImplementation: RemoteConfigurationService {
    private let api: RemoteConfigurationAPI
    private let repository: RemoteConfigurationRepository

    init(
        api: RemoteConfigurationAPI,
        repository: RemoteConfigurationRepository
    ) {
        self.api = api
        self.repository = repository
    }

    func getConfiguration() throws -> RemoteConfigurations {
        try repository.configuration
    }

    func loadConfiguration() async throws -> RemoteConfigurations {
        let configuration = try await api.loadConfiguration()
        try? repository.saveConfiguration(configuration)
        return configuration
    }
}

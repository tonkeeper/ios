import Foundation

public final class ConfigurationAssembly {
    private let remoteConfigurationAPIAssembly: RemoteConfigurationAPIAssembly
    private let coreAssembly: CoreAssembly

    init(
        remoteConfigurationAPIAssembly: RemoteConfigurationAPIAssembly,
        coreAssembly: CoreAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.remoteConfigurationAPIAssembly = remoteConfigurationAPIAssembly
    }

    private weak var _configuration: Configuration?
    public var configuration: Configuration {
        if let configuration = _configuration {
            return configuration
        } else {
            let configuration = Configuration(remoteConfigurationService: remoteConfigurationService())
            _configuration = configuration
            return configuration
        }
    }

    func remoteConfigurationService() -> RemoteConfigurationService {
        RemoteConfigurationServiceImplementation(
            api: remoteConfigurationAPIAssembly.api,
            repository: remoteConfigurationRepository()
        )
    }

    func remoteConfigurationRepository() -> RemoteConfigurationRepository {
        RemoteConfigurationRepositoryImplementation(
            fileSystemVault: coreAssembly.fileSystemVault()
        )
    }
}

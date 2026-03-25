import Foundation
import TKFeatureFlags

public final class ConfigurationAssembly {
    private let remoteConfigurationAPIAssembly: RemoteConfigurationAPIAssembly
    private let coreAssembly: CoreAssembly
    private let featureFlags: TKFeatureFlags
    private let tkAppSettings: TKAppSettings

    init(
        remoteConfigurationAPIAssembly: RemoteConfigurationAPIAssembly,
        featureFlags: TKFeatureFlags,
        tkAppSettings: TKAppSettings,
        coreAssembly: CoreAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.featureFlags = featureFlags
        self.tkAppSettings = tkAppSettings
        self.remoteConfigurationAPIAssembly = remoteConfigurationAPIAssembly
    }

    private weak var _configuration: Configuration?
    public var configuration: Configuration {
        if let configuration = _configuration {
            return configuration
        } else {
            let configuration = Configuration(
                remoteConfigurationService: remoteConfigurationService(),
                featureFlags: featureFlags,
                tkAppSettings: tkAppSettings
            )
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

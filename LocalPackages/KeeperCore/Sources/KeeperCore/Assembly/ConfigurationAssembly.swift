import Foundation
import PerpsModels
import TKFeatureFlags
import TKLogging

public final class ConfigurationAssembly {
    private let bootConfigurationAPIAssembly: BootConfigurationAPIAssembly
    private let coreAssembly: CoreAssembly
    private let featureFlags: TKFeatureFlags
    private let tkAppSettings: TKAppSettings

    init(
        bootConfigurationAPIAssembly: BootConfigurationAPIAssembly,
        featureFlags: TKFeatureFlags,
        tkAppSettings: TKAppSettings,
        coreAssembly: CoreAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.featureFlags = featureFlags
        self.tkAppSettings = tkAppSettings
        self.bootConfigurationAPIAssembly = bootConfigurationAPIAssembly
    }

    private weak var _configuration: Configuration?
    public var configuration: Configuration {
        if let configuration = _configuration {
            return configuration
        } else {
            let configuration = Configuration(
                bootConfigurationService: bootConfigurationService(),
                featureFlags: featureFlags,
                tkAppSettings: tkAppSettings,
                perpsAccessOverride: StaticFlagOverrides.shared?.perpsAccessOverride
            )
            _configuration = configuration
            return configuration
        }
    }

    func bootConfigurationService() -> BootConfigurationService {
        BootConfigurationServiceImplementation(
            api: bootConfigurationAPIAssembly.api,
            repository: bootConfigurationRepository()
        )
    }

    func bootConfigurationRepository() -> BootConfigurationRepository {
        BootConfigurationRepositoryImplementation(
            fileSystemVault: coreAssembly.fileSystemVault()
        )
    }
}

private extension StaticFlagOverrides {
    var perpsAccessOverride: PerpsAccess? {
        guard let perpsAccess else { return nil }
        guard let access = PerpsAccess(rawValue: perpsAccess) else {
            Log.w("StaticFlagOverrides: perpsAccess must be one of available, restricted, hidden, got \"\(perpsAccess)\"; ignored")
            return nil
        }
        return access
    }
}

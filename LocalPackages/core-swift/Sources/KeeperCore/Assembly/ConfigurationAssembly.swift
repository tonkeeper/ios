import Foundation

public final class ConfigurationAssembly {
  
  private let tonkeeperApiAssembly: TonkeeperAPIAssembly
  private let coreAssembly: CoreAssembly
  
  init(tonkeeperApiAssembly: TonkeeperAPIAssembly,
       coreAssembly: CoreAssembly) {
    self.tonkeeperApiAssembly = tonkeeperApiAssembly
    self.coreAssembly = coreAssembly
  }
//  
//  private weak var _remoteConfigurationStore: ConfigurationStore?
//  public var remoteConfigurationStore: ConfigurationStore {
//    if let remoteConfigurationStore = _remoteConfigurationStore {
//      return remoteConfigurationStore
//    } else {
//      let remoteConfigurationStore = ConfigurationStore(
//        configurationService: remoteConfigurationService()
//      )
//      _remoteConfigurationStore = remoteConfigurationStore
//      return remoteConfigurationStore
//    }
//  }
  
  func remoteConfigurationService() -> RemoteConfigurationService {
    RemoteConfigurationServiceImplementation(
      api: tonkeeperApiAssembly.api,
      repository: remoteConfigurationRepository()
    )
  }
  
  func remoteConfigurationRepository() -> RemoteConfigurationRepository {
    RemoteConfigurationRepositoryImplementation(
      fileSystemVault: coreAssembly.fileSystemVault()
    )
  }
  
  private weak var _configurationStore: ConfigurationStore?
  public var configurationStore: ConfigurationStore {
    if let configurationStore = _configurationStore {
      return configurationStore
    } else {
      let configurationStore = ConfigurationStore(repository: remoteConfigurationRepository())
      _configurationStore = configurationStore
      return configurationStore
    }
  }
  
  private weak var _configurationLoader: ConfigurationLoader?
  public var configurationLoader: ConfigurationLoader {
    if let configurationLoader = _configurationLoader {
      return configurationLoader
    } else {
      let configurationLoader = ConfigurationLoader(
        configurationStore: configurationStore,
        configurationService: remoteConfigurationService()
      )
      _configurationLoader = configurationLoader
      return configurationLoader
    }
  }
}

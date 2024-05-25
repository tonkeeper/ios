import Foundation

public final class ConfigurationAssembly {
  
  private let tonkeeperApiAssembly: TonkeeperAPIAssembly
  private let coreAssembly: CoreAssembly
  
  init(tonkeeperApiAssembly: TonkeeperAPIAssembly,
       coreAssembly: CoreAssembly) {
    self.tonkeeperApiAssembly = tonkeeperApiAssembly
    self.coreAssembly = coreAssembly
  }
  
  private weak var _remoteConfigurationStore: ConfigurationStore?
  public var remoteConfigurationStore: ConfigurationStore {
    if let remoteConfigurationStore = _remoteConfigurationStore {
      return remoteConfigurationStore
    } else {
      let remoteConfigurationStore = ConfigurationStore(
        configurationService: remoteConfigurationService()
      )
      _remoteConfigurationStore = remoteConfigurationStore
      return remoteConfigurationStore
    }
  }
  
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
}

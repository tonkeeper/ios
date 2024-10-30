import Foundation

public final class ConfigurationAssembly {
  
  private let tonkeeperApiAssembly: TonkeeperAPIAssembly
  private let coreAssembly: CoreAssembly
  
  init(tonkeeperApiAssembly: TonkeeperAPIAssembly,
       coreAssembly: CoreAssembly) {
    self.tonkeeperApiAssembly = tonkeeperApiAssembly
    self.coreAssembly = coreAssembly
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

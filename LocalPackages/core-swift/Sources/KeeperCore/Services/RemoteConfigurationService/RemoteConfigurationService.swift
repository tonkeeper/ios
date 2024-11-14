import Foundation

protocol RemoteConfigurationService {
  func getConfiguration() throws -> RemoteConfigurations
  func loadConfiguration() async throws -> RemoteConfigurations
}

final class RemoteConfigurationServiceImplementation: RemoteConfigurationService {
  private let api: TonkeeperAPI
  private let repository: RemoteConfigurationRepository
  
  init(api: TonkeeperAPI,
       repository: RemoteConfigurationRepository) {
    self.api = api
    self.repository = repository
  }
  
  func getConfiguration() throws -> RemoteConfigurations {
    try repository.configuration
  }
  
  func loadConfiguration() async throws -> RemoteConfigurations {
    let configuration = try await api.loadConfiguration(
      lang: .lang,
      build: .build,
      chainName: .chainName,
      platform: .platform
    )
    try? repository.saveConfiguration(configuration)
    return configuration
  }
}

private extension String {
  static let lang = "en"
  static let build = "3.6.2"
  static let chainName = "mainnet"
  static let platform = "ios"
}

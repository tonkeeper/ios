import Foundation

protocol RemoteConfigurationService {
  func getConfiguration() throws -> RemoteConfiguration
  func loadConfiguration() async throws -> RemoteConfiguration
}

final class RemoteConfigurationServiceImplementation: RemoteConfigurationService {
  private let api: TonkeeperAPI
  private let repository: RemoteConfigurationRepository
  
  init(api: TonkeeperAPI,
       repository: RemoteConfigurationRepository) {
    self.api = api
    self.repository = repository
  }
  
  func getConfiguration() throws -> RemoteConfiguration {
    try repository.configuration
  }
  
  func loadConfiguration() async throws -> RemoteConfiguration {
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

import Foundation
import CoreComponents

enum RemoteConfigurationRepositoryError: Swift.Error {
  case noDefaultConfigurationInBundle
  case defaultConfigurationCorrupted(error: Swift.Error)
}

protocol RemoteConfigurationRepository {
  var configuration: RemoteConfiguration { get throws }
  
  func saveConfiguration(_ configuration: RemoteConfiguration) throws
}

struct RemoteConfigurationRepositoryImplementation: RemoteConfigurationRepository {
  let fileSystemVault: FileSystemVault<RemoteConfiguration, String>
  
  init(fileSystemVault: FileSystemVault<RemoteConfiguration, String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func saveConfiguration(_ configuration: RemoteConfiguration) throws {
    try fileSystemVault.saveItem(configuration, key: .fileVaultConfigurationKey)
  }
  
  var configuration: RemoteConfiguration {
    get throws {
      if let configuration = try? fileSystemVault.loadItem(key: .fileVaultConfigurationKey) {
        return configuration
      }
      
      guard let url = Bundle.module.url(forResource: .defaultConfigurationFileName, withExtension: nil),
            let data = try? Data(contentsOf: url) else {
        throw RemoteConfigurationRepositoryError.noDefaultConfigurationInBundle
      }
      
      let decoder = JSONDecoder()
      do {
        let configuration = try decoder.decode(RemoteConfiguration.self, from: data)
        return configuration
      } catch {
        throw RemoteConfigurationRepositoryError.defaultConfigurationCorrupted(error: error)
      }
    }
  }
}

private extension String {
  static let fileVaultConfigurationKey = "RemoteConfiguration"
  static let defaultConfigurationFileName = "DefaultRemoteConfiguration.json"
}

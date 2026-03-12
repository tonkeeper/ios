import CoreComponents
import Foundation

enum RemoteConfigurationRepositoryError: Swift.Error {
    case noDefaultConfigurationInBundle
    case defaultConfigurationCorrupted(error: Swift.Error)
}

protocol RemoteConfigurationRepository {
    var configuration: RemoteConfigurations { get throws }

    func saveConfiguration(_ configuration: RemoteConfigurations) throws
}

struct RemoteConfigurationRepositoryImplementation: RemoteConfigurationRepository {
    let fileSystemVault: FileSystemVault<RemoteConfigurations, String>

    func saveConfiguration(_ configuration: RemoteConfigurations) throws {
        try fileSystemVault.saveItem(configuration, key: .fileVaultConfigurationKey)
    }

    var configuration: RemoteConfigurations {
        get throws {
            if let configuration = try? fileSystemVault.loadItem(key: .fileVaultConfigurationKey) {
                return configuration
            }

            guard let url = Bundle.module.url(forResource: .defaultConfigurationFileName, withExtension: nil),
                  let data = try? Data(contentsOf: url)
            else {
                throw RemoteConfigurationRepositoryError.noDefaultConfigurationInBundle
            }

            let decoder = JSONDecoder()
            do {
                return try decoder.decode(RemoteConfigurations.self, from: data)
            } catch {
                throw RemoteConfigurationRepositoryError.defaultConfigurationCorrupted(error: error)
            }
        }
    }
}

private extension String {
    static let fileVaultConfigurationKey = "RemoteConfigurations"
    static let defaultConfigurationFileName = "DefaultRemoteConfiguration.json"
}

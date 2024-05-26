import Foundation
import CoreComponents

protocol PopularAppsRepository {
  func savePopularApps(_ popularApps: PopularAppsResponseData, lang: String) throws
  func getPopularApps(lang: String) throws -> PopularAppsResponseData
}

final class PopularAppsRepositoryImplementation: PopularAppsRepository {
  let fileSystemVault: FileSystemVault<PopularAppsResponseData, String>
  
  init(fileSystemVault: FileSystemVault<PopularAppsResponseData, String>) {
    self.fileSystemVault = fileSystemVault
  }
  
  func savePopularApps(_ popularApps: PopularAppsResponseData, lang: String) throws {
    let key: String = "\(String.key)_\(lang)"
    try fileSystemVault.saveItem(popularApps, key: key)
  }
  
  func getPopularApps(lang: String) throws -> PopularAppsResponseData {
    let key: String = "\(String.key)_\(lang)"
    return try fileSystemVault.loadItem(key: key)
  }
}

private extension String {
  static let key = "PopularApps"
}

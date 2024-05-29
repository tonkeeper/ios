import Foundation

public protocol PopularAppsService {
  func loadPopularApps(lang: String) async throws -> PopularAppsResponseData
  func getPopularApps(lang: String) throws -> PopularAppsResponseData
  func savePopularApps(_ popularApps: PopularAppsResponseData, lang: String) throws
}

final class PopularAppsServiceImplementation: PopularAppsService {
  private let api: TonkeeperAPI
  private let popularAppsRepository: PopularAppsRepository
  
  init(api: TonkeeperAPI,
       popularAppsRepository: PopularAppsRepository) {
    self.api = api
    self.popularAppsRepository = popularAppsRepository
  }
  
  func loadPopularApps(lang: String) async throws -> PopularAppsResponseData {
    try await api.loadPopularApps(lang: lang)
  }
  
  func getPopularApps(lang: String) throws -> PopularAppsResponseData {
    try popularAppsRepository.getPopularApps(lang: lang)
  }
  
  func savePopularApps(_ popularApps: PopularAppsResponseData, lang: String) throws {
    try popularAppsRepository.savePopularApps(popularApps, lang: lang)
  }
}

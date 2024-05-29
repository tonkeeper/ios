import Foundation

public final class BrowserExploreController {
  
  private let popularAppsService: PopularAppsService
  
  init(popularAppsService: PopularAppsService) {
    self.popularAppsService = popularAppsService
  }
  
  public func getCachedPopularApps(lang: String) throws -> PopularAppsResponseData {
    try popularAppsService.getPopularApps(lang: lang)
  }
  
  public func loadPopularApps(lang: String) async throws -> PopularAppsResponseData {
    do {
      let apps = try await popularAppsService.loadPopularApps(lang: lang)
      try? popularAppsService.savePopularApps(apps, lang: lang)
      return apps
    } catch {
      try? popularAppsService.savePopularApps(.empty, lang: lang)
      throw error
    }
  }
}

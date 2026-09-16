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
        try await popularAppsService.loadPopularApps(lang: lang)
    }
}

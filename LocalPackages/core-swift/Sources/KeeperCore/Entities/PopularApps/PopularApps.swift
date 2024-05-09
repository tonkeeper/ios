import Foundation

public struct PopularApp: Codable {
  public let name: String?
  public let description: String?
  public let icon: URL?
  public let poster: URL?
  public let url: URL?
  public let textColor: String?
}

public struct PopularAppsCategory: Codable {
  public let id: String
  public let title: String?
  public let apps: [PopularApp]
}

public struct PopularApps: Codable {
  public let categories: [PopularAppsCategory]
  public let apps: [PopularApp]
}

public struct PopularAppsResponseData: Codable {
  public let moreEnabled: Bool
  public let apps: [PopularApp]
  public let categories: [PopularAppsCategory]
}

public struct PopularAppsResponse: Codable {
  public let data: PopularAppsResponseData
}

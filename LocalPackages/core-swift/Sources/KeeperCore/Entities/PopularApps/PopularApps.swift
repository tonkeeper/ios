import Foundation

public struct PopularAppsCategory: Codable {
  public let id: String
  public let title: String?
  public let apps: [PopularApp]
}

public struct PopularApps: Codable {
  public let categories: [PopularAppsCategory]
  public let apps: [PopularApp]
}

public struct PopularApp: Codable, Identifiable, Equatable {
  public let id: String
  public let name: String
  public let description: String?
  public let icon: URL?
  public let poster: URL?
  public let url: URL?
  public let textColor: String?
  public let excludeCountries: [String]?
  public let includeCountries: [String]?
  
  public init(id: String,
              name: String,
              description: String?,
              icon: URL?,
              poster: URL?,
              url: URL?,
              textColor: String?,
              excludeCountries: [String]?,
              includeCountries: [String]?) {
    self.id = id
    self.name = name
    self.description = description
    self.icon = icon
    self.poster = poster
    self.url = url
    self.textColor = textColor
    self.excludeCountries = excludeCountries
    self.includeCountries = includeCountries
  }
}


public struct PopularAppsResponseData: Codable {
  public let moreEnabled: Bool
  public let apps: [PopularApp]
  public let categories: [PopularAppsCategory]
  
  public static var empty: PopularAppsResponseData {
    PopularAppsResponseData(
      moreEnabled: false,
      apps: [],
      categories: []
    )
  }
}

public struct PopularAppsResponse: Codable {
  public let data: PopularAppsResponseData
}

public extension PopularAppsResponseData {

  var defiCategory: PopularAppsCategory? {
    categories.first(where: { $0.id == "defi" })
  }
}

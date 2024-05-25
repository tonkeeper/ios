import Foundation

public struct PopularAppsCategory: Codable {
  public let id: String
  public let title: String?
  public let apps: [Dapp]
}

public struct PopularApps: Codable {
  public let categories: [PopularAppsCategory]
  public let apps: [Dapp]
}

public struct PopularAppsResponseData: Codable {
  public let moreEnabled: Bool
  public let apps: [Dapp]
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

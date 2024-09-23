import Foundation

public struct Country: Codable {
  public let alpha2: String
  public let alpha3: String
  public let ru: String
  public let en: String
  public let flag: String
}

public enum SelectedCountry: Codable, Equatable {
  case auto
  case all
  case country(countryCode: String)
}

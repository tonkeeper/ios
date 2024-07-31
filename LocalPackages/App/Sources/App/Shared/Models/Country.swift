import Foundation

struct Country: Codable {
  let alpha2: String
  let alpha3: String
  let ru: String
  let en: String
  let flag: String
}

enum SelectedCountry: Codable {
  case auto
  case all
  case country(countryCode: String)
}

import Foundation

public enum SelectedCountry: Codable, Equatable {
    case auto
    case all
    case country(countryCode: String)
}

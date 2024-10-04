import Foundation
import KeeperCore

final class CountriesProvider {
  private var _countries: [Country]?
  var countries: [Country] {
    get {
      if let _countries {
        return _countries
      } else {
        guard let url = Bundle.module.url(forResource: .countriesListName, withExtension: nil) else {
          return []
        }
        do {
          let data = try Data(contentsOf: url)
          let countries = try JSONDecoder().decode(Countries.self, from: data)
          _countries = countries.country
          return countries.country
        } catch {
          return []
        }
      }
    }
  }
}

private struct Countries: Codable {
  let country: [Country]
}

private extension String {
  static let countriesListName = "countries_list.json"
}

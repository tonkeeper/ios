import Foundation
import KeeperCore

final class CountryPickerDataSource {
  var countries = [Country]()
  
  let selectedCountry: Country?
  
  init(selectedCountry: Country?) {
    self.selectedCountry = selectedCountry
  }
}

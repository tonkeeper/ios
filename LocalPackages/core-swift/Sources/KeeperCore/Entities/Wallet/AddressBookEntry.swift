import Foundation

struct AddressBookEntry: Codable {
  let address: ResolvableAddress
  let label: String
}

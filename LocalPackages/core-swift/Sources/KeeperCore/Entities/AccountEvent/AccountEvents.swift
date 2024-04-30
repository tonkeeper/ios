import Foundation
import TonSwift

struct AccountEvents: Codable {  
  let address: Address
  let events: [AccountEvent]
  let startFrom: Int64
  let nextFrom: Int64
}

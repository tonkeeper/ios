import Foundation
import TonSwift

public struct AccountEvents: Codable {
  public let address: Address
  public let events: [AccountEvent]
  public let startFrom: Int64
  public let nextFrom: Int64
}

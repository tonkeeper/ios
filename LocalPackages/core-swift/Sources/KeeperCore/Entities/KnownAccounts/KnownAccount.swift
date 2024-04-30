import Foundation
import TonSwift

public struct KnownAccount: Codable {
  public let address: Address
  public let name: String
  public let requireMemo: Bool
  public let imageUrl: URL?
  
  enum CodingKeys: String, CodingKey {
    case address
    case name
    case requireMemo = "require_memo"
    case imageUrl = "image"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let addressString = try container.decode(String.self, forKey: .address)
    self.address = try Address.parse(addressString)
    self.name = try container.decode(String.self, forKey: .name)
    self.requireMemo = try container.decodeIfPresent(Bool.self, forKey: .requireMemo) ?? false
    self.imageUrl = try container.decodeIfPresent(URL.self, forKey: .imageUrl)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let addressString = address.toRaw()
    try container.encode(addressString, forKey: .address)
    try container.encode(self.name, forKey: .name)
    try container.encode(self.requireMemo, forKey: .requireMemo)
    try container.encodeIfPresent(self.imageUrl, forKey: .imageUrl)
  }
}

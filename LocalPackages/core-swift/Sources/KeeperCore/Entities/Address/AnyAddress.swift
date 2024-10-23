import TonSwift

public enum AnyAddress: Decodable {
  public enum Error: Swift.Error {
    case incorrencyRawAddress(rawAddress: String)
  }
  
  case address(Address)
  case friendlyAddress(FriendlyAddress)
  
  public var address: Address {
    switch self {
    case .address(let address):
      return address
    case .friendlyAddress(let friendlyAddress):
      return friendlyAddress.address
    }
  }
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawAddress = try container.decode(String.self)
    if let friendlyAddress = try? FriendlyAddress(string: rawAddress) {
      self = .friendlyAddress(friendlyAddress)
    } else if let address = try? Address.parse(raw: rawAddress) {
      self = .address(address)
    } else {
      throw Error.incorrencyRawAddress(rawAddress: rawAddress)
    }
  }
}

import Foundation
import TonSwift

public struct Recipient: Equatable {
  public enum RecipientAddress: Equatable {
    case friendly(FriendlyAddress)
    case raw(Address)
    case domain(Domain)
    
    public var address: Address {
      switch self {
      case .friendly(let friendlyAddress):
        return friendlyAddress.address
      case .raw(let address):
        return address
      case .domain(let domain):
        return domain.friendlyAddress.address
      }
    }
    
    public var addressString: String {
      switch self {
      case .friendly(let friendlyAddress):
        return friendlyAddress.toString()
      case .raw(let address):
        return address.toRaw()
      case .domain(let domain):
        return domain.friendlyAddress.toString()
      }
    }
    
    public var shortAddressString: String {
      switch self {
      case .friendly(let friendlyAddress):
        return friendlyAddress.toShort()
      case .raw(let address):
        return address.toShortRawString()
      case .domain(let domain):
        return domain.friendlyAddress.toShort()
      }
    }
    
    public var name: String? {
      switch self {
      case .domain(let domain):
        return domain.domain
      default:
        return nil
      }
    }
    
    public var isBouncable: Bool {
      switch self {
      case .friendly(let friendlyAddress):
        return friendlyAddress.isBounceable
      case .raw:
        return false
      case .domain(let domain):
        return domain.friendlyAddress.isBounceable
      }
    }
  }
  
  public let recipientAddress: RecipientAddress
  public let isMemoRequired: Bool
  
  public init(recipientAddress: RecipientAddress, isMemoRequired: Bool) {
    self.recipientAddress = recipientAddress
    self.isMemoRequired = isMemoRequired
  }
}

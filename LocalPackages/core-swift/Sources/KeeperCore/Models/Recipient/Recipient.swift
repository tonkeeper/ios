import Foundation

public enum Recipient: Equatable {
  case ton(TonRecipient)
  case tron(TronRecipient)
  
  public var isTon: Bool {
    switch self {
    case .ton:
      true
    default:
      false
    }
  }
  
  public var isTron: Bool {
    switch self {
    case .tron:
      true
    default:
      false
    }
  }
  
  public var tonRecipient: TonRecipient? {
    switch self {
    case let .ton(tonRecipient):
      tonRecipient
    default:
      nil
    }
  }
  
  public var tronRecipient: TronRecipient? {
    switch self {
    case let .tron(tronRecipient):
      tronRecipient
    default:
      nil
    }
  }
  
  public var isCommentRequired: Bool {
    switch self {
    case .ton(let tonRecipient):
      tonRecipient.isMemoRequired
    case .tron:
      false
    }
  }
  
  public var stringValue: String {
    switch self {
    case .ton(let tonRecipient):
      tonRecipient.recipientAddress.addressString
    case .tron(let tronRecipient):
      tronRecipient.base58
    }
  }
}

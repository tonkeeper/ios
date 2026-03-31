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
        case let .ton(tonRecipient):
            tonRecipient.isMemoRequired
        case .tron:
            false
        }
    }

    public var isScam: Bool {
        switch self {
        case let .ton(tonRecipient):
            tonRecipient.isScam
        case .tron:
            false
        }
    }

    public var stringValue: String {
        switch self {
        case let .ton(tonRecipient):
            tonRecipient.recipientAddress.addressString
        case let .tron(tronRecipient):
            tronRecipient.base58
        }
    }
}

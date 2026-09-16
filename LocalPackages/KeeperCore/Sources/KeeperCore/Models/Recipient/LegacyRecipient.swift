import Foundation

public enum LegacyRecipient: Equatable {
    case ton(TonRecipient)
    case tron(TronRecipient)

    public var isTon: Bool {
        switch self {
        case .ton:
            true
        case .tron:
            false
        }
    }

    public var isTron: Bool {
        switch self {
        case .tron:
            true
        case .ton:
            false
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

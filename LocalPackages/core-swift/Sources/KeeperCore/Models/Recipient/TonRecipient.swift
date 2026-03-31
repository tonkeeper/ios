import Foundation
import TonSwift

public struct TonRecipient: Equatable {
    public enum RecipientAddress: Equatable {
        case friendly(FriendlyAddress)
        case raw(Address)
        case domain(Domain)

        public var address: Address {
            switch self {
            case let .friendly(friendlyAddress):
                return friendlyAddress.address
            case let .raw(address):
                return address
            case let .domain(domain):
                return domain.friendlyAddress.address
            }
        }

        public var addressString: String {
            switch self {
            case let .friendly(friendlyAddress):
                return friendlyAddress.toString()
            case let .raw(address):
                return address.toRaw()
            case let .domain(domain):
                return domain.friendlyAddress.toString()
            }
        }

        public var shortAddressString: String {
            switch self {
            case let .friendly(friendlyAddress):
                return friendlyAddress.toShort()
            case let .raw(address):
                return address.toShortRawString()
            case let .domain(domain):
                return domain.friendlyAddress.toShort()
            }
        }

        public var name: String? {
            switch self {
            case let .domain(domain):
                return domain.domain
            default:
                return nil
            }
        }

        public var isBouncable: Bool {
            switch self {
            case let .friendly(friendlyAddress):
                return friendlyAddress.isBounceable
            case .raw:
                return false
            case let .domain(domain):
                return domain.friendlyAddress.isBounceable
            }
        }
    }

    public let recipientAddress: RecipientAddress
    public let isMemoRequired: Bool
    public let isScam: Bool

    public init(recipientAddress: RecipientAddress, isMemoRequired: Bool, isScam: Bool) {
        self.recipientAddress = recipientAddress
        self.isMemoRequired = isMemoRequired
        self.isScam = isScam
    }
}

import Foundation
import TonSwift

public enum DNSLink {
    public enum LinkAddress: Equatable {
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

    case link(address: LinkAddress)
    case unlink
}

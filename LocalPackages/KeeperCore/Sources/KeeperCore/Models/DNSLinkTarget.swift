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
    }

    case link(address: LinkAddress)
    case unlink
}

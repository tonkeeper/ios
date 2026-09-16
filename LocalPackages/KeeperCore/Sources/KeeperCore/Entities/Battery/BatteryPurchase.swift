import Foundation

public struct BatteryPurchase: Equatable {
    public enum Kind: Equatable {
        case ios
        case android
        case promocode
        case crypto
        case gift
        case onTheWayGift

        public var isStorePurchase: Bool {
            switch self {
            case .ios, .android:
                return true
            case .promocode, .crypto, .gift, .onTheWayGift:
                return false
            }
        }
    }

    public let identifier: Int
    public let kind: Kind
    /// Charges already taken back, fully or partially. A refund awaiting review is not one.
    public let isRefunded: Bool

    public init(identifier: Int, kind: Kind, isRefunded: Bool) {
        self.identifier = identifier
        self.kind = kind
        self.isRefunded = isRefunded
    }
}

import Foundation

enum PerpsLimitOrderChangeSettlement {
    static func activeOrderConfirms(
        change: PerpsPendingLimitOrderChange,
        price: Double
    ) -> Bool {
        guard change.kind == .modify, let target = change.limitPrice else { return false }
        return pricesMatch(price, target)
    }

    static func inactiveOrderConfirms(
        change: PerpsPendingLimitOrderChange,
        price: Double,
        isCanceled: Bool
    ) -> Bool {
        switch change.kind {
        case .modify:
            return change.limitPrice.map { pricesMatch(price, $0) } == true
        case .cancel:
            return isCanceled
        }
    }

    static func pricesMatch(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= max(1e-9, max(abs(lhs), abs(rhs)) * 1e-12)
    }
}

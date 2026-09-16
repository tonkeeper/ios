import Foundation

public enum BalanceFreshness: Hashable, Sendable {
    case pending
    case actual
}

public enum BalanceAmount {
    public static let animationDuration: TimeInterval = 0.35
    public static let shimmerDelay: TimeInterval = 0.3
}

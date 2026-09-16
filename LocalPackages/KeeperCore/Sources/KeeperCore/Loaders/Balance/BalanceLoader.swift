import Foundation

/// Ordered by who is waiting. Quiet is a budget handed to an owner, and each owner names the lowest
/// priority it still lets through, so the gate is a comparison rather than a case-by-case rule.
public enum BalanceRefreshPriority: Int, Comparable, Sendable {
    /// Streaming, the periodic tick, the wallets-list prefill. Nobody is watching an indicator.
    case background
    /// Settles a balance a screen is rendering as pending.
    case userVisible
    /// Someone is waiting on this exact data. Opening a screen does not qualify on its own.
    case userInitiated

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Whether landing on a run already in flight earns a follow-up run of its own. A refresh that
    /// reports a change may have been read past by the run in flight, and someone pulling to
    /// refresh is asking for an answer newer than the one it is fetching. A screen that has just
    /// appeared wants no more than that answer, so it rides it — asking again would spend a second
    /// request to be told the same thing, and leave the screen loading for both.
    var earnsFollowUpRun: Bool {
        self != .userVisible
    }
}

public enum BalanceRefreshResult: Equatable {
    case delivered(WalletBalanceState)
    /// A reload ran and produced no new balance.
    case failed
    /// Nothing ran and nothing is coming, so this says nothing about the amount on screen.
    case dropped
}

/// What the loader knew at the moment it notified, so a consumer that hops isolation domains no
/// longer reads a flag that has since moved on.
public struct BalanceLoaderUpdate {
    public let wallet: Wallet
    public let isLoading: Bool
    /// `nil` on the start edge.
    public let result: BalanceRefreshResult?
}

public protocol BalanceLoader: AnyObject {
    /// Runs as soon as the current mode allows one. A request landing on a reload already queued or
    /// in flight rides it and reports its result rather than adding its own. Always returns.
    @discardableResult
    func reloadBalance(wallet: Wallet, priority: BalanceRefreshPriority) async -> BalanceRefreshResult
    /// Every wallet whose balance is stale enough to be worth a request. Results reach the screens
    /// through the stores, since no single caller is waiting for a particular wallet here.
    func reloadAllWalletsBalance(priority: BalanceRefreshPriority) async
    func setQuiet(_ isQuiet: Bool, owner: BalanceQuietOwner)
    func setRegularPollingPaused(_ paused: Bool)
    func setIsRealtimeSubscribed(_ isSubscribed: @escaping @Sendable (String) -> Bool)
    func addUpdateObserver<T: AnyObject>(_ observer: T, closure: @escaping (T, BalanceLoaderUpdate) -> Void)
}

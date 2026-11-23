import Foundation

/// Wallets that sent an Earn transaction within the last minute. The positions the backend loads
/// right after a transaction may predate it, so every portfolio load of such a wallet asks the
/// backend to load them again rather than reuse what it has.
public actor EarnPortfolioDirtyFlags {
    static let window: TimeInterval = 60

    private let uptime: @Sendable () -> TimeInterval
    private var markedAt = [String: TimeInterval]()

    init(uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.uptime = uptime
    }

    public func markDirty(wallet: Wallet) {
        markedAt[wallet.id] = uptime()
    }

    func isDirty(wallet: Wallet) -> Bool {
        guard let marked = markedAt[wallet.id] else { return false }
        guard uptime() - marked < Self.window else {
            markedAt[wallet.id] = nil
            return false
        }
        return true
    }
}

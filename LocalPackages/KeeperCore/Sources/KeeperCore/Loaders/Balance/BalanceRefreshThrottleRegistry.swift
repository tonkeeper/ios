import Foundation

/// One throttle per wallet plus the one pacing the wallets-list sweep, created on first use and
/// kept for as long as the wallet is.
final class BalanceRefreshThrottleRegistry {
    private let makeWalletThrottle: (Wallet) -> BalanceRefreshThrottle
    private let makeAllWalletsThrottle: () -> BalanceRefreshThrottle

    private let lock = NSLock()
    private var walletThrottles = [Wallet: BalanceRefreshThrottle]()
    private var sweepThrottle: BalanceRefreshThrottle?

    init(
        makeWalletThrottle: @escaping (Wallet) -> BalanceRefreshThrottle,
        makeAllWalletsThrottle: @escaping () -> BalanceRefreshThrottle
    ) {
        self.makeWalletThrottle = makeWalletThrottle
        self.makeAllWalletsThrottle = makeAllWalletsThrottle
    }

    func throttle(for wallet: Wallet) -> BalanceRefreshThrottle {
        lock.withLock {
            if let throttle = walletThrottles[wallet] {
                return throttle
            }
            let throttle = makeWalletThrottle(wallet)
            walletThrottles[wallet] = throttle
            return throttle
        }
    }

    /// The run that reports a result has to be checked against the throttle that started it, and a
    /// wallet nobody has asked for has no run to check.
    func existingThrottle(for wallet: Wallet) -> BalanceRefreshThrottle? {
        lock.withLock { walletThrottles[wallet] }
    }

    func allWalletsThrottle() -> BalanceRefreshThrottle {
        lock.withLock {
            if let sweepThrottle {
                return sweepThrottle
            }
            let throttle = makeAllWalletsThrottle()
            sweepThrottle = throttle
            return throttle
        }
    }

    @discardableResult
    func remove(wallet: Wallet) -> BalanceRefreshThrottle? {
        lock.withLock { walletThrottles.removeValue(forKey: wallet) }
    }

    func cancelAll() {
        let throttles = lock.withLock { () -> [BalanceRefreshThrottle] in
            Array(walletThrottles.values) + [sweepThrottle].compactMap { $0 }
        }
        for throttle in throttles {
            throttle.cancel()
        }
    }
}

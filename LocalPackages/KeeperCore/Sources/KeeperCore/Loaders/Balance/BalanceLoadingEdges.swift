import Foundation

/// Who is loading right now, and who wants to be told. A wallet can be loading for its own screen
/// and for the wallets-list sweep at once, so what the observers see is a count rather than
/// whichever edge fired last.
final class BalanceLoadingEdges {
    private let observers = LockedObserverStore<BalanceLoaderUpdate>()
    private let lock = NSLock()
    private var loadsInFlight = [Wallet: Int]()

    func addObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, BalanceLoaderUpdate) -> Void
    ) {
        observers.add(observer, closure: closure)
    }

    func begin(wallet: Wallet) {
        publish(wallet: wallet, delta: 1, result: nil)
    }

    func end(wallet: Wallet, result: BalanceRefreshResult) {
        publish(wallet: wallet, delta: -1, result: result)
    }

    private func publish(wallet: Wallet, delta: Int, result: BalanceRefreshResult?) {
        let isLoading = lock.withLock { () -> Bool in
            let count = max(0, (loadsInFlight[wallet] ?? 0) + delta)
            loadsInFlight[wallet] = count == 0 ? nil : count
            return count > 0
        }
        observers.notify(
            BalanceLoaderUpdate(wallet: wallet, isLoading: isLoading, result: result)
        )
    }
}

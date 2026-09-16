import Foundation

/// The loader that performs a wallet's fan-out, kept for the wallets the app knows about.
final class WalletBalanceLoaderRegistry {
    private let makeLoader: (Wallet) -> WalletBalanceLoader

    private let lock = NSLock()
    private var loaders: [Wallet: WalletBalanceLoader]

    init(wallets: [Wallet], makeLoader: @escaping (Wallet) -> WalletBalanceLoader) {
        self.makeLoader = makeLoader
        loaders = wallets.reduce(into: [Wallet: WalletBalanceLoader]()) { $0[$1] = makeLoader($1) }
    }

    func loader(for wallet: Wallet) -> WalletBalanceLoader? {
        lock.withLock { loaders[wallet] }
    }

    /// A wallet already known keeps the loader it has, since a run may be in flight on it.
    func add(wallets: [Wallet]) {
        let added = wallets.reduce(into: [Wallet: WalletBalanceLoader]()) { $0[$1] = makeLoader($1) }
        lock.withLock {
            loaders.merge(added, uniquingKeysWith: { old, _ in old })
        }
    }

    func remove(wallet: Wallet) {
        lock.withLock { loaders.removeValue(forKey: wallet) }
    }
}

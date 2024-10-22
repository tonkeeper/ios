import Foundation
import TonSwift

public final class BalanceLoader {
  private var observers = [UUID: (Wallet) -> Void]()
  private let lock = NSLock()
  
  private var balanceLoadTask: Task<Void, Never>?
  private var reloadTask: Task<Void, Never>?
  
  private var walletBalanceLoaders = [Wallet: WalletBalanceLoader]()
  
  private let walletStore: WalletsStore
  private let currencyStore: CurrencyStore
  private let ratesStore: TonRatesStore
  private let ratesService: RatesService
  private let walletStateLoaderProvider: (Wallet) -> WalletBalanceLoader
  
  init(walletStore: WalletsStore,
       currencyStore: CurrencyStore,
       ratesStore: TonRatesStore,
       ratesService: RatesService,
       walletStateLoaderProvider: @escaping (Wallet) -> WalletBalanceLoader) {
    self.walletStore = walletStore
    self.currencyStore = currencyStore
    self.ratesStore = ratesStore
    self.ratesService = ratesService
    self.walletStateLoaderProvider = walletStateLoaderProvider
    
    walletBalanceLoaders = walletStore.wallets.reduce(into: [Wallet: WalletBalanceLoader]()) {
      $0[$1] = createWalletBalanceLoader(wallet: $1)
    }
    
    setupObservations()
  }
  
  public func isLoadingBalance(wallet: Wallet) -> Bool {
    walletBalanceLoaders[wallet]?.isLoading ?? false
  }
  
  public func loadActiveWalletBalance() {
    guard let activeWallet = try? walletStore.activeWallet else { return }
    balanceLoadTask?.cancel()
    
    let walletBalanceLoader = walletBalanceLoaders[activeWallet]
    let task = Task {
      let currency = currencyStore.state
      await loadRates(currency: currency)
      await walletBalanceLoader?.reloadBalance(currency: currency)
    }
    balanceLoadTask = task
  }
  
  public func loadAllWalletsBalance() {
    balanceLoadTask?.cancel()
    let loaders = walletStore.wallets.compactMap { walletBalanceLoaders[$0] }
    let task = Task {
      let currency = currencyStore.state
      await loadRates(currency: currency)
      let chunks = loaders.chunked(into: 2)
      for chunk in chunks {
        await withTaskGroup(of: Void.self) { group in
          for loader in chunk {
            group.addTask {
              await loader.reloadBalance(currency: currency)
            }
          }
          await group.waitForAll()
        }
      }
    }
    balanceLoadTask = task
  }
  
  public func startActiveWalletBalanceReload() {
    reloadTask?.cancel()
    let task = Task {
      try? await Task.sleep(nanoseconds: 60_000_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        loadActiveWalletBalance()
        startActiveWalletBalanceReload()
      }
    }
    reloadTask = task
  }
  
  public func stopActiveWalletBalanceReload() {
    reloadTask?.cancel()
  }
  
  public func addUpdateObserver<T: AnyObject>(_ observer: T,
                                              closure: @escaping (T, Wallet) -> Void) {
    let id = UUID()
    let observerClosure: (Wallet) -> Void = { [weak self, weak observer] wallet in
      guard let self else { return }
      guard let observer else {
        self.observers.removeValue(forKey: id)
        return
      }
      closure(observer, wallet)
    }
    lock.withLock {
      self.observers[id] = observerClosure
    }
  }
  
  private func setupObservations() {
    walletStore.addObserver(self) { observer, event in
      DispatchQueue.main.async {
        switch event {
        case .didAddWallets(let wallets):
          let loaders = wallets.reduce(into: [Wallet: WalletBalanceLoader]()) {
            $0[$1] = observer.createWalletBalanceLoader(wallet: $1)
          }
          observer.walletBalanceLoaders.merge(loaders, uniquingKeysWith: { old, _ in old })
        case .didDeleteWallet(let wallet):
          observer.walletBalanceLoaders[wallet] = nil
        case .didChangeActiveWallet:
          observer.loadActiveWalletBalance()
          observer.startActiveWalletBalanceReload()
        default: break
        }
      }
    }
    
    currencyStore.addObserver(self) { observer, event in
      DispatchQueue.main.async {
        switch event {
        case .didUpdateCurrency:
          observer.loadActiveWalletBalance()
          observer.startActiveWalletBalanceReload()
        }
      }
    }
  }
  
  private func createWalletBalanceLoader(wallet: Wallet) -> WalletBalanceLoader {
    let loader = walletStateLoaderProvider(wallet)
    loader.addUpdateObserver(self, closure: { observer in
      let observers = observer.lock.withLock {
        observer.observers
      }
      observers.forEach { $0.value(wallet) }
    })
    return loader
  }
  
  private func loadRates(currency: Currency) async {
    do {
      let rates = try await ratesService.loadRates(jettons: [], currencies: [currency, .TON, .USD]).ton
      try Task.checkCancellation()
      await ratesStore.setRates(rates)
    } catch {
      guard !error.isCancelledError else { return }
      await ratesStore.setRates([])
    }
  }
}

private extension Array {
  func chunked(into size: Int) -> [[Element]] {
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0 ..< Swift.min($0 + size, count)])
    }
  }
}

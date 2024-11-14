import Foundation

public final class WalletBalanceLoader {
  
  private(set) public var isLoading: Bool = false
  private var balanceLoadTask: Task<Void, Never>?
  private let lock = NSLock()
  private var observers = [UUID: () -> Void]()
  
  private let wallet: Wallet
  private let balanceStore: BalanceStore
  private let stakingPoolsStore: StakingPoolsStore
  private let walletNFTSStore: WalletNFTStore
  private let ratesStore: TonRatesStore
  private let balanceService: BalanceService
  private let stackingService: StakingService
  private let accountNFTService: AccountNFTService
  private let ratesService: RatesService
  
  init(wallet: Wallet,
       balanceStore: BalanceStore,
       stakingPoolsStore: StakingPoolsStore,
       walletNFTSStore: WalletNFTStore,
       ratesStore: TonRatesStore,
       balanceService: BalanceService,
       stackingService: StakingService,
       accountNFTService: AccountNFTService,
       ratesService: RatesService) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.stakingPoolsStore = stakingPoolsStore
    self.walletNFTSStore = walletNFTSStore
    self.ratesStore = ratesStore
    self.balanceService = balanceService
    self.stackingService = stackingService
    self.accountNFTService = accountNFTService
    self.ratesService = ratesService
  }
  
  public func reloadBalance(currency: Currency) async {
    lock.withLock {
      self.balanceLoadTask?.cancel()
      
      self.isLoading = true
      self.observers.forEach { $0.value() }
      let task = Task {
        await loadAll(currency: currency)
        lock.withLock {
          self.isLoading = false
          self.observers.forEach { $0.value() }
          self.balanceLoadTask = nil
        }
      }
      self.balanceLoadTask = task
    }
  }
  
  public func cancel() {
    lock.withLock {
      self.balanceLoadTask?.cancel()
    }
  }
  
  public func addUpdateObserver<T: AnyObject>(_ observer: T,
                                              closure: @escaping (T) -> Void) {
    let id = UUID()
    let observerClosure: () -> Void = { [weak self, weak observer] in
      guard let self else { return }
      guard let observer else {
        self.observers.removeValue(forKey: id)
        return
      }
      closure(observer)
    }
    lock.withLock {
      self.observers[id] = observerClosure
    }
  }
  
  private func loadAll(currency: Currency) async {
    async let balanceTask: Void = loadBalance(currency: currency)
    async let stakingPoolsTask: Void = loadStakingPools()
    async let nftsTask: Void = loadNFTs()
    
    await balanceTask
    await stakingPoolsTask
    await nftsTask
  }
  
  private func loadBalance(currency: Currency) async {
    do {
      let balance = try await balanceService.loadWalletBalance(wallet: wallet, currency: currency)
      try Task.checkCancellation()
      await balanceStore.setBalanceState(.current(balance), wallet: wallet)
    } catch {
      guard !error.isCancelledError else { return }
      guard let balanceState = self.balanceStore.state[wallet] else {
        return
      }
      await self.balanceStore.setBalanceState(.previous(balanceState.walletBalance), wallet: wallet)
    }
  }
  
  private func loadStakingPools() async {
    guard let stackingPools = try? await self.stackingService.loadStakingPools(wallet: wallet),
    !Task.isCancelled else {
      return
    }
    await stakingPoolsStore.setStackingPools(stackingPools, wallet: wallet)
  }
  
  private func loadNFTs() async {
    do {
      let nfts = try await self.accountNFTService.loadAccountNFTs(
        wallet: wallet,
        collectionAddress: nil,
        limit: nil,
        offset: nil,
        isIndirectOwnership: true
      )
      try Task.checkCancellation()
      await walletNFTSStore.setNFTs(nfts, wallet: wallet)
    } catch {
      guard error.isCancelledError else { return }
    }
  }
}

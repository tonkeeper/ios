import Foundation
import TonSwift

public final class WalletStateLoaderV2 {
  
  // MARK: - Sync
  
  private let syncQueue = DispatchQueue(label: "WalletStateLoaderSyncQueue")
  
  // MARK: - State
  
  private var balanceLoadTasks = [Wallet: Task<Void, Never>]()
  private var nftLoadTasks = [Wallet: Task<Void, Never>]()
  private var reloadTask: Task<Void, Never>?
  private var ratesLoadTask: Task<[Rates.Rate], Swift.Error>?
  
  // MARK: - Dependencies
  
  private let walletsStore: WalletsStore
  private let balanceStore: BalanceStore
  private let currencyStore: CurrencyStore
  private let stakingPoolsStore: StakingPoolsStore
  private let walletNFTSStore: WalletNFTStore
  private let ratesStore: TonRatesStore
  private let balanceService: BalanceService
  private let stackingService: StakingService
  private let accountNFTService: AccountNFTService
  private let ratesService: RatesService
  
  // MARK: - Init
  
  init(walletsStore: WalletsStore, 
       balanceStore: BalanceStore,
       currencyStore: CurrencyStore,
       stakingPoolsStore: StakingPoolsStore,
       walletNFTSStore: WalletNFTStore,
       ratesStore: TonRatesStore,
       balanceService: BalanceService,
       stackingService: StakingService,
       accountNFTService: AccountNFTService,
       ratesService: RatesService) {
    self.walletsStore = walletsStore
    self.balanceStore = balanceStore
    self.currencyStore = currencyStore
    self.stakingPoolsStore = stakingPoolsStore
    self.walletNFTSStore = walletNFTSStore
    self.ratesStore = ratesStore
    self.balanceService = balanceService
    self.stackingService = stackingService
    self.accountNFTService = accountNFTService
    self.ratesService = ratesService
  }
  
  public func loadActiveWalletBalance() {
    
  }
  
  public func loadWalletsBalance() {
    
  }

  public func startReload() {
    
  }
  
  public func stopReload() {
    
  }
  
  private func loadBalances(wallets: [Wallet], currency: Currency) {
    
  }
  
  private func loadWalletState(wallet: Wallet, currency: Currency) {
    syncQueue.async {
      if let balanceLoadTask = self.balanceLoadTasks[wallet] {
        balanceLoadTask.cancel()
      }
      self.balanceLoadTasks[wallet] = nil
      
      let balanceLoadTask = self.loadWalletBalanceTask(wallet: wallet, currency: currency)
      
      self.syncQueue.async {
        
      }
      
//      let task = Task {
//        do {
//          async let loadBalanceTask = self.balanceService.loadWalletBalance(wallet: wallet, currency: currency)
//          async let loadStakingPoolTask = self.stackingService.loadStakingPools(wallet: wallet)
//          async let loadNFTsTask = self.accountNFTService.loadAccountNFTs(
//            wallet: wallet,
//            collectionAddress: nil,
//            limit: nil,
//            offset: nil,
//            isIndirectOwnership: true
//          )
//          
//          let balance = try await loadBalanceTask
//          let stakingPools = (try? await loadStakingPoolTask) ?? []
//          let nfts = try await loadNFTsTask
//          
//          try Task.checkCancellation()
//          await self.balanceStore.setBalanceState(.current(balance), wallet: wallet)
//          await self.stakingPoolsStore.setStackingPools(stakingPools, wallet: wallet)
//          await self.walletNFTSStore.setNFTs(nfts, wallet: wallet)
//        } catch {
//          guard !error.isCancelledError else { return }
//          guard let balanceState = await self.balanceStore.getState()[wallet] else {
//            return
//          }
      //          await self.balanceStore.setBalanceState(.previous(balanceState.walletBalance), wallet: wallet)
      //        }
      //        self.syncQueue.async {
      //          self.balanceLoadTasks[wallet] = nil
      //        }
    }
    
    //      self.balanceLoadTasks[wallet] = task
  }
  
  private func loadWalletBalanceTask(wallet: Wallet, currency: Currency) -> Task<Void, Never> {
    Task {
      do {
        async let loadBalanceTask = self.balanceService.loadWalletBalance(wallet: wallet, currency: currency)
        async let loadStakingPoolTask = self.stackingService.loadStakingPools(wallet: wallet)
        
        let balance = try await loadBalanceTask
        let stakingPools = (try? await loadStakingPoolTask) ?? []
        
        try Task.checkCancellation()
        
        await balanceStore.setBalanceState(.current(balance), wallet: wallet)
        await stakingPoolsStore.setStackingPools(stakingPools, wallet: wallet)
      } catch {
        guard !error.isCancelledError else { return }
        guard let balanceState = await self.balanceStore.getState()[wallet] else {
          return
        }
        await self.balanceStore.setBalanceState(.previous(balanceState.walletBalance), wallet: wallet)
      }
    }
  }
  
  private func loadWalletNFTs(wallet: Wallet) async {
    
  }
  
}

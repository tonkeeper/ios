import Foundation
import TonSwift
import BigInt

protocol BalanceService {
  func loadWalletBalance(wallet: Wallet, currency: Currency) async throws -> WalletBalance
  func getBalance(wallet: Wallet) throws -> WalletBalance
}

final class BalanceServiceImplementation: BalanceService {
  private let tonBalanceService: TonBalanceService
  private let jettonsBalanceService: JettonBalanceService
  private let stakingPoolService: StakingPoolsService
  private let accountStakingInfoService: AccountStakingInfoService
  private let walletBalanceRepository: WalletBalanceRepository

  init(tonBalanceService: TonBalanceService,
       jettonsBalanceService: JettonBalanceService,
       stakingPoolService: StakingPoolsService,
       accountStakingInfoService: AccountStakingInfoService,
       walletBalanceRepository: WalletBalanceRepository) {
    self.tonBalanceService = tonBalanceService
    self.jettonsBalanceService = jettonsBalanceService
    self.walletBalanceRepository = walletBalanceRepository
    self.stakingPoolService = stakingPoolService
    self.accountStakingInfoService = accountStakingInfoService
  }
 
  func loadWalletBalance(wallet: Wallet, currency: Currency) async throws -> WalletBalance {
    async let tonBalanceTask = tonBalanceService.loadBalance(wallet: wallet)
    async let jettonsBalanceTask = jettonsBalanceService.loadJettonsBalance(wallet: wallet, currency: currency)
    async let stakingTask = loadStakingBalance(wallet: wallet)
    
    let tonBalance = try await tonBalanceTask
    let jettonsBalance = try await jettonsBalanceTask
    let stakingData = try await stakingTask
    
    let stakingBalances = stakingData.balances
    let stakingPools = stakingData.pools
    
    let filteredJettonBalances = filterNonStakedJettonBalances(
      jettonBalances: jettonsBalance,
      stakingPools: stakingPools
    )
    
    let mergedStakingBalances = mergeStakedBalances(
      jettonBalances: jettonsBalance,
      stakingPools: stakingPools,
      stakingBalances: stakingBalances
    )
    
    let balance = Balance(
      tonBalance: tonBalance,
      jettonsBalance: filteredJettonBalances,
      stakingBalance: mergedStakingBalances
    )
    
    let walletBalance = WalletBalance(
      date: Date(),
      balance: balance
    )
    
    try? walletBalanceRepository.saveWalletBalance(
      walletBalance, 
      for: wallet
    )
    
    return walletBalance
  }
  
  func getBalance(wallet: Wallet) throws -> WalletBalance {
    try walletBalanceRepository.getWalletBalance(wallet: wallet)
  }
}

// MARK: - Private methods

private extension BalanceServiceImplementation {
  func filterNonStakedJettonBalances(
    jettonBalances: [JettonBalance],
    stakingPools: [StakingPool]
  ) -> [JettonBalance] {
    let pools = stakingPools.compactMap { $0.jettonMaster }
    return jettonBalances.filter { !pools.contains($0.item.jettonInfo.address) }
  }
  
  // We need to merge staked jetton balances from liquidTF to display the correct balance.
  // They are not returning in balance requet if unstake request in progress.
  // The opposite thing with nominators, they are not returning in balance request when deposit or
  // unstake is in progress
  func mergeStakedBalances(
    jettonBalances: [JettonBalance],
    stakingPools: [StakingPool],
    stakingBalances: [StakingBalance]
  ) -> [StakingBalance] {
    let pools = stakingPools.compactMap { $0.jettonMaster }
    let stakedJettonBalances = jettonBalances.filter { pools.contains($0.item.jettonInfo.address) }
    
    /// Check if jetton has processing deposit or unstaking and update amount
    let updated: [StakingBalance] = stakingBalances.map { balance -> StakingBalance in
      guard let jettonMaster = balance.pool.jettonMaster else {
        return balance
      }
      
      guard let jettonBalance = jettonBalances.first(where: { $0.item.jettonInfo.address == jettonMaster }) else  {
        return balance
      }
      
      return .init(
        pool: balance.pool,
        amount: jettonBalance.quantity,
        pendingDeposit: balance.pendingDeposit,
        pendingWithdraw: balance.pendingWithdraw,
        readyWithdraw: balance.readyWithdraw
      )
    }
    
    /// Append if jettons finished deposit or withdraw processing and has balance
    var appended: [StakingBalance] = []
    let updatedJettonMasters = updated.compactMap { $0.pool.jettonMaster }
    for jettonBalance in stakedJettonBalances {
      if !updatedJettonMasters.contains(jettonBalance.item.jettonInfo.address) {
        guard let pool = stakingPools.first(where: { $0.jettonMaster ==  jettonBalance.item.jettonInfo.address}) else {
          continue
        }
        
        appended.append(
          .init(
            pool: pool,
            amount: jettonBalance.quantity,
            pendingDeposit: .zero,
            pendingWithdraw: .zero,
            readyWithdraw: .zero
          )
        )
      }
    }
    
    return updated + appended
  }
  
  func loadStakingBalance(wallet: Wallet) async throws -> (balances: [StakingBalance], pools: [StakingPool])  {
    async let stakingPoolsTask = stakingPoolService.loadAvailablePools(
      address: wallet.address,
      isTestnet: wallet.isTestnet,
      includeUnverified: false
    )
    
    async let accountStakingInfoTask = accountStakingInfoService.loadAccountStakingInfo(address: wallet.address, isTestnet: wallet.isTestnet)
    
    let stakingPools = try await stakingPoolsTask
    let accountStakingInfo = try await accountStakingInfoTask
    
    let stakingBalances = accountStakingInfo.compactMap { accountInfo -> StakingBalance? in
      guard let stakingPool = stakingPools.first(where: { $0.address == accountInfo.address }) else {
        return nil
      }
      
      return .init(
        pool: stakingPool,
        amount: accountInfo.amount,
        pendingDeposit: accountInfo.pendingDeposit,
        pendingWithdraw: accountInfo.pendingWithdraw,
        readyWithdraw: accountInfo.readyToWithdraw
      )
    }
    
    return (balances: stakingBalances, pools: stakingPools)
  }
}

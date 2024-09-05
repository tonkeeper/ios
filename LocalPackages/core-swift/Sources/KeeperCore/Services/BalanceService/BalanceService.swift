import Foundation
import TonSwift
import BigInt

public protocol BalanceService {
  func loadWalletBalance(wallet: Wallet, currency: Currency) async throws -> WalletBalance
  func getBalance(wallet: Wallet) throws -> WalletBalance
}

final class BalanceServiceImplementation: BalanceService {
  private let tonBalanceService: TonBalanceService
  private let jettonsBalanceService: JettonBalanceService
  private let stackingService: StakingService
  private let walletBalanceRepository: WalletBalanceRepository
  
  init(tonBalanceService: TonBalanceService, 
       jettonsBalanceService: JettonBalanceService,
       stackingService: StakingService,
       walletBalanceRepository: WalletBalanceRepository) {
    self.tonBalanceService = tonBalanceService
    self.jettonsBalanceService = jettonsBalanceService
    self.stackingService = stackingService
    self.walletBalanceRepository = walletBalanceRepository
  }
 
  func loadWalletBalance(wallet: Wallet, currency: Currency) async throws -> WalletBalance {
    async let tonBalanceTask = tonBalanceService.loadBalance(wallet: wallet)
    async let jettonsBalanceTask = jettonsBalanceService.loadJettonsBalance(wallet: wallet, currency: currency)
    async let stackingBalanceTask = stackingService.loadStakingBalance(wallet: wallet)
    
    let tonBalance = try await tonBalanceTask
    let jettonsBalance = try await jettonsBalanceTask
    
    let stackingBalance: [AccountStackingInfo]
    do {
      stackingBalance = try await stackingBalanceTask
    } catch {
      stackingBalance = []
    }
    
    let balance = Balance(
      tonBalance: tonBalance,
      jettonsBalance: jettonsBalance
    )
    
    let walletBalance = WalletBalance(
      date: Date(),
      balance: balance,
      stacking: stackingBalance
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

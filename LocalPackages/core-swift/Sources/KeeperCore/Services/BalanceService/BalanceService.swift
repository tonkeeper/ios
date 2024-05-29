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
  private let walletBalanceRepository: WalletBalanceRepository
  
  init(tonBalanceService: TonBalanceService, 
       jettonsBalanceService: JettonBalanceService,
       walletBalanceRepository: WalletBalanceRepository) {
    self.tonBalanceService = tonBalanceService
    self.jettonsBalanceService = jettonsBalanceService
    self.walletBalanceRepository = walletBalanceRepository
  }
 
  func loadWalletBalance(wallet: Wallet, currency: Currency) async throws -> WalletBalance {
    async let tonBalanceTask = tonBalanceService.loadBalance(wallet: wallet)
    async let jettonsBalanceTask = jettonsBalanceService.loadJettonsBalance(wallet: wallet, currency: currency)
    
    let tonBalance = try await tonBalanceTask
    let jettonsBalance = try await jettonsBalanceTask
    
    let balance = Balance(
      tonBalance: tonBalance,
      jettonsBalance: jettonsBalance
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

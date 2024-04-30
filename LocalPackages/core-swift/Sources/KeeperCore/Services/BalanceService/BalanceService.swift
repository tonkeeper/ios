import Foundation
import TonSwift
import BigInt

protocol BalanceService {
  func loadWalletBalance(address: Address, currency: Currency) async throws -> WalletBalance
  func getBalance(address: Address) throws -> WalletBalance
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
 
  func loadWalletBalance(address: Address, currency: Currency) async throws -> WalletBalance {
    async let tonBalanceTask = tonBalanceService.loadBalance(address: address)
    async let jettonsBalanceTask = jettonsBalanceService.loadJettonsBalance(address: address, currency: currency)
    
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
      for: address
    )
    
    return walletBalance
  }
  
  func getBalance(address: Address) throws -> WalletBalance {
    try walletBalanceRepository.getWalletBalance(address: address)
  }
}

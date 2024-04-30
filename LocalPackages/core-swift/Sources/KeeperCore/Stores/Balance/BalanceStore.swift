import Foundation
import TonSwift

actor BalanceStore {
  public struct Event {
    public let wallet: Wallet
    public let result: Result<WalletBalance, Swift.Error>
  }
  
  private var tasksInProgress = [Wallet: Task<(), Swift.Error>]()
  
  private let balanceService: BalanceService
  
  init(balanceService: BalanceService) {
    self.balanceService = balanceService
  }
  
  nonisolated
  func getBalance(wallet: Wallet) throws -> WalletBalance {
    return try balanceService.getBalance(address: wallet.address)
  }
}

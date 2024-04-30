import Foundation
import TonSwift

actor WalletBalanceLoader {
  private var tasksInProgress = [Address: Task<(), Never>]()

  private let walletBalanceStore: WalletBalanceStore
  private let balanceService: BalanceService
  
  init(walletBalanceStore: WalletBalanceStore,
       balanceService: BalanceService) {
    self.walletBalanceStore = walletBalanceStore
    self.balanceService = balanceService
  }
  
  func loadBalance(walletAddress: Address, currency: Currency) {
    if let taskInProgress = tasksInProgress[walletAddress] {
      taskInProgress.cancel()
      tasksInProgress[walletAddress] = nil
    }
    
    let task = Task {
      do {
        let balance = try await balanceService
          .loadWalletBalance(address: walletAddress, currency: currency)
        guard !Task.isCancelled else { return }
        await walletBalanceStore.setBalanceState(.current(balance), walletAddress: walletAddress)
      } catch {
        guard !error.isCancelledError else { return }
        if let balance = try? await walletBalanceStore.getBalanceState(walletAddress: walletAddress).walletBalance {
          await walletBalanceStore.setBalanceState(.previous(balance), walletAddress: walletAddress)
        }
      }
    }
    tasksInProgress[walletAddress] = task
  }
}

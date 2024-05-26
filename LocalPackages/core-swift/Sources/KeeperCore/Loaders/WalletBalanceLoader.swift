import Foundation
import TonSwift

actor WalletBalanceLoader {
  private var tasksInProgress = [FriendlyAddress: Task<(), Never>]()

  private let walletBalanceStore: WalletBalanceStore
  private let balanceService: BalanceService
  
  init(walletBalanceStore: WalletBalanceStore,
       balanceService: BalanceService) {
    self.walletBalanceStore = walletBalanceStore
    self.balanceService = balanceService
  }
  
  func loadBalance(wallet: Wallet, currency: Currency) {
    guard let address = try? wallet.friendlyAddress else { return }
    if let taskInProgress = tasksInProgress[address] {
      taskInProgress.cancel()
      tasksInProgress[address] = nil
    }
    
    let task = Task {
      do {
        let balance = try await balanceService
          .loadWalletBalance(wallet: wallet, currency: currency)
        guard !Task.isCancelled else { return }
        await walletBalanceStore.setBalanceState(.current(balance), wallet: wallet)
      } catch {
        guard !error.isCancelledError else { return }
        if let balance = try? await walletBalanceStore.getBalanceState(wallet: wallet).walletBalance {
          await walletBalanceStore.setBalanceState(.previous(balance), wallet: wallet)
        }
      }
    }
    tasksInProgress[address] = task
  }
}

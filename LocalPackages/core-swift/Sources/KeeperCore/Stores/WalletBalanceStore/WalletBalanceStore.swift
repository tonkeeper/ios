import Foundation
import TonSwift

public actor WalletBalanceStore {
  typealias ObservationClosure = (Event) -> Void
  enum Event {
    case balanceUpdate(balance: WalletBalanceState, wallet: Wallet)
  }
  
  private var balanceStates = [FriendlyAddress: WalletBalanceState]()
  
  private let repository: WalletBalanceRepository
  
  init(repository: WalletBalanceRepository) {
    self.repository = repository
  }
  
  func getBalanceState(wallet: Wallet) throws -> WalletBalanceState {
    let address = try wallet.friendlyAddress
    if let balanceState = balanceStates[address] {
      return balanceState
    } else {
      let balance = try repository.getWalletBalance(wallet: wallet)
      let balanceState = WalletBalanceState.previous(balance)
      balanceStates[address] = balanceState
      return balanceState
    }
  }
  
  func setBalanceState(_ balanceState: WalletBalanceState, wallet: Wallet) {
    guard let address = try? wallet.friendlyAddress else { return }
    balanceStates[address] = balanceState
    try? repository.saveWalletBalance(balanceState.walletBalance,for: wallet)
    observations.values.forEach { $0(.balanceUpdate(balance: balanceState, wallet: wallet)) }
  }
  
  private var observations = [UUID: ObservationClosure]()
  
  func addEventObserver<T: AnyObject>(_ observer: T,
                                      closure: @escaping (T, Event) -> Void) -> ObservationToken {
    let id = UUID()
    let eventHandler: (Event) -> Void = { [weak self, weak observer] event in
      guard let self else { return }
      guard let observer else {
        Task { await self.removeObservation(key: id) }
        return
      }
      
      closure(observer, event)
    }
    observations[id] = eventHandler
    
    return ObservationToken { [weak self] in
      guard let self else { return }
      Task { await self.removeObservation(key: id) }
    }
  }
  
  func removeObservation(key: UUID) {
    observations.removeValue(forKey: key)
  }
}

public class ObservationToken {
  private let cancellationClosure: () -> Void
  
  init(cancellationClosure: @escaping () -> Void) {
    self.cancellationClosure = cancellationClosure
  }
  
  public func cancel() {
    cancellationClosure()
  }
}

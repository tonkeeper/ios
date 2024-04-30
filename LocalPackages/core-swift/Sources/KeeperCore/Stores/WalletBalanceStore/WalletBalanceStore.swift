import Foundation
import TonSwift

actor WalletBalanceStore {
  typealias ObservationClosure = (Event) -> Void
  enum Event {
    case balanceUpdate(balance: WalletBalanceState, walletAddress: Address)
  }
  
  private var balanceStates = [Address: WalletBalanceState]()
  
  private let repository: WalletBalanceRepository
  
  init(repository: WalletBalanceRepository) {
    self.repository = repository
  }
  
  func getBalanceState(walletAddress: Address) throws -> WalletBalanceState {
    if let balanceState = balanceStates[walletAddress] {
      return balanceState
    } else {
      let balance = try repository.getWalletBalance(address: walletAddress)
      let balanceState = WalletBalanceState.previous(balance)
      balanceStates[walletAddress] = balanceState
      return balanceState
    }
  }
  
  func setBalanceState(_ balanceState: WalletBalanceState, walletAddress: Address) {
    balanceStates[walletAddress] = balanceState
    try? repository.saveWalletBalance(balanceState.walletBalance, for: walletAddress)
    observations.values.forEach { $0(.balanceUpdate(balance: balanceState, walletAddress: walletAddress)) }
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

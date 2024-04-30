import Foundation

protocol RatesStoreObserver: AnyObject {
  func didGetRatesStoreEvent(_ event: RatesStore.Event)
}

actor RatesStore {
  
  enum Event {
    case updateRates(rates: Rates, wallet: Wallet)
  }
  
  private var tasksInProgress = [Wallet: Task<(), Never>]()
  
  private let ratesService: RatesService
  
  init(ratesService: RatesService) {
    self.ratesService = ratesService
  }
  
  func loadRates(jettons: [JettonInfo], wallet: Wallet) {
    if let taskInProgress = tasksInProgress[wallet] {
      taskInProgress.cancel()
      tasksInProgress[wallet] = nil
    }
    
    let task = Task {
      let rates: Rates
      do {
        rates = try await ratesService.loadRates(
          jettons: jettons,
          currencies: Currency.allCases
        )
      } catch {
        rates = Rates(ton: [], jettonsRates: [])
      }
      guard !Task.isCancelled else { return }
      notifyObservers(event: .updateRates(rates: rates, wallet: wallet))
      tasksInProgress[wallet] = nil
    }
    tasksInProgress[wallet] = task
  }
  
  nonisolated
  func getRates(jettons: [JettonInfo]) -> Rates {
    return ratesService.getRates(jettons: jettons)
  }
  
  struct RatesStoreObserverWrapper {
    weak var observer: RatesStoreObserver?
  }
  
  private var observers = [RatesStoreObserverWrapper]()
  
  func addObserver(_ observer: RatesStoreObserver) {
    removeNilObservers()
    observers = observers + CollectionOfOne(RatesStoreObserverWrapper(observer: observer))
  }
  
  func removeObserver(_ observer: RatesStoreObserver) {
    removeNilObservers()
    observers = observers.filter { $0.observer !== observer }
  }
}

private extension RatesStore {
  func removeNilObservers() {
    observers = observers.filter { $0.observer != nil }
  }

  func notifyObservers(event: RatesStore.Event) {
    observers.forEach { $0.observer?.didGetRatesStoreEvent(event) }
  }
}

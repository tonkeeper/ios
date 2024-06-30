import Foundation
import TonSwift

actor TonRatesLoaderV2 {
  struct State: Equatable {
    let currency: Currency?
  }
  
  private var taskInProgress: Task<(), Never>?
  private var state = State(currency: nil) {
    didSet {
      guard state != oldValue else { return }
      Task {
        await reloadRates(state: state, oldState: oldValue)
      }
    }
  }
  
  private let tonRatesStore: TonRatesStoreV2
  private let ratesService: RatesService
  private let currencyStore: CurrencyStoreV2
  
  init(tonRatesStore: TonRatesStoreV2, 
       ratesService: RatesService,
       currencyStore: CurrencyStoreV2) {
    self.tonRatesStore = tonRatesStore
    self.ratesService = ratesService
    self.currencyStore = currencyStore
    currencyStore.addObserver(self, notifyOnAdded: true) { observer, currency, _ in
      Task { await observer.didUpdateCurrency(currency) }
    }
  }
  
  nonisolated
  func reloadRates() {
    Task {
      guard let currency = await self.state.currency else { return }
      await self.reloadRates(currency: currency)
    }
  }
}

private extension TonRatesLoaderV2 {
  func didUpdateCurrency(_ currency: Currency) {
    let newState = State(currency: currency)
    self.state = newState
  }
  
  func reloadRates(state: State, oldState: State) async {
    guard let currency = state.currency else { return }
    guard currency != oldState.currency else { return }
    await reloadRates(currency: currency)
  }
  
  func reloadRates(currency: Currency) async {
    if let task = taskInProgress {
      task.cancel()
      self.taskInProgress = nil
    }
    
    let task = Task {
      do {
        let rates = try await ratesService.loadRates(
          jettons: [],
          currencies: [currency, .TON]
        ).ton
        guard !Task.isCancelled else { return }
        await tonRatesStore.setRates(rates)
      } catch {
        guard !error.isCancelledError else { return }
        await tonRatesStore.setRates([])
      }
    }
    taskInProgress = task
  }
}

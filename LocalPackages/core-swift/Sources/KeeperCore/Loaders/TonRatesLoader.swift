import Foundation
import TonSwift

actor TonRatesLoader {
  private var taskInProgress: Task<(), Swift.Error>?
  
  private let tonRatesStore: TonRatesStore
  private let ratesService: RatesService
  
  init(tonRatesStore: TonRatesStore,
       ratesService: RatesService) {
    self.tonRatesStore = tonRatesStore
    self.ratesService = ratesService
  }
  
  func loadRate(currency: Currency) async {
    if let taskInProgress = taskInProgress {
      taskInProgress.cancel()
      self.taskInProgress = nil
    }
    
    let task = Task {
      let tonRates = try await ratesService
        .loadRates(jettons:[], currencies: [currency, .USD, .TON]).ton
      
      guard !Task.isCancelled else { return }
      await tonRatesStore.setTonRates(tonRates)
    }
    
    taskInProgress = task
  }
}

import Foundation

public final class TonRatesStoreV2: Store<[Rates.Rate]> {
  
  private let repository: RatesRepository
  
  init(repository: RatesRepository) {
    self.repository = repository
    super.init(state: [])
    self.setInitialState()
  }
  
  public func getRates() async -> [Rates.Rate] {
    await getState()
  }
  
  public func setRates(_ rates: [Rates.Rate]) async {
    await updateState { [repository] _ in
      try? repository.saveRates(Rates(ton: rates, jettonsRates: []))
      return StateUpdate(newState: rates)
    }
  }
  
  private func setInitialState() {
    Task {
      await updateState { [repository] _ in
        let rates = (try? repository.getRates(jettons: []).ton) ?? []
        return StateUpdate(newState: rates)
      }
    }
  }
}

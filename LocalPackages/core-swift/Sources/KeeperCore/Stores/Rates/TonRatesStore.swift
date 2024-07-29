import Foundation

public final class TonRatesStore: StoreUpdated<[Rates.Rate]> {
  
  private let repository: RatesRepository
  
  init(repository: RatesRepository) {
    self.repository = repository
    super.init(state: [])
  }
  
  public func setTonRates(_ rates: [Rates.Rate], completion: (() -> Void)?) {
    updateState { [repository] _ in
      try? repository.saveRates(Rates(ton: rates, jettonsRates: []))
      return StateUpdate(newState: rates)
    } completion: {
      completion?()
    }
  }
  
  public func setTonRates(_ rates: [Rates.Rate]) async {
    await updateState { [repository] _ in
      try? repository.saveRates(Rates(ton: rates, jettonsRates: []))
      return StateUpdate(newState: rates)
    }
  }

  public override func getInitialState() -> [Rates.Rate] {
    do {
      return try repository.getRates(jettons: []).ton
    } catch {
      return []
    }
  }
}

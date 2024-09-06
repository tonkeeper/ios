import Foundation

public final class TonRatesStoreV3: StoreV3<TonRatesStoreV3.Event, TonRatesStoreV3.State> {
  public typealias State = [Rates.Rate]
  
  public enum Event {
    case didUpdateTonRates(rates: [Rates.Rate])
  }
  
  private let repository: RatesRepository
  
  init(repository: RatesRepository) {
    self.repository = repository
    super.init(state: [])
  }
  
  public override var initialState: State {
    do {
      return try repository.getRates(jettons: []).ton
    } catch {
      return []
    }
  }

  public func setRates(_ rates: [Rates.Rate]) async {
    await setState { [repository] _ in
      try? repository.saveRates(Rates(ton: rates, jettonsRates: []))
      return StateUpdate(newState: rates)
    } notify: { state in
      self.sendEvent(.didUpdateTonRates(rates: state))
    }
  }
}

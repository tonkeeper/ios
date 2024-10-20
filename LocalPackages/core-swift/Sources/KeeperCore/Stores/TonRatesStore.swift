import Foundation

public final class TonRatesStore: StoreV3<TonRatesStore.Event, TonRatesStore.State> {
  public typealias State = [Rates.Rate]
  
  public enum Event {
    case didUpdateTonRates(rates: [Rates.Rate])
  }
  
  private let repository: RatesRepository
  
  init(repository: RatesRepository) {
    self.repository = repository
    super.init(state: [])
  }
  
  public override func createInitialState() -> State {
    do {
      return try repository.getRates(jettons: []).ton
    } catch {
      return []
    }
  }
  
  public func setRates(_ rates: [Rates.Rate]) async {
    return await withCheckedContinuation { continuation in
      setRates(rates) {
        continuation.resume()
      }
    }
  }
  
  public func setRates(_ rates: [Rates.Rate],
                       completion: @escaping () -> Void) {
    updateState { [repository] _ in
      try? repository.saveRates(Rates(ton: rates, jettonsRates: []))
      return StateUpdate(newState: rates)
    } completion: { [weak self] state in
      guard let self else { return }
      self.sendEvent(.didUpdateTonRates(rates: state))
      completion()
    }
  }
}

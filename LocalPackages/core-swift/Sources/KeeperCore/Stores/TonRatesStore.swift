import Foundation

public final class TonRatesStore: Store<TonRatesStore.Event, TonRatesStore.State> {
  public struct State {
    public let tonRates: [Rates.Rate]
    public let usdtRates: [Rates.Rate]
  }
  
  public enum Event {
    case didUpdateRates(state: State)
  }
  
  private let repository: RatesRepository
  
  init(repository: RatesRepository) {
    self.repository = repository
    super.init(state: State(tonRates: [], usdtRates: []))
  }
  
  public override func createInitialState() -> State {
    do {
      let rates = try repository.getRates()
      return State(tonRates: rates.ton, usdtRates: rates.usdt)
    } catch {
      return State(tonRates: [], usdtRates: [])
    }
  }
  
  public func setRates(ton: [Rates.Rate],
                       usdt: [Rates.Rate]) async {
    return await withCheckedContinuation { continuation in
      setRates(ton: ton, usdt: usdt) {
        continuation.resume()
      }
    }
  }
  
  public func setRates(ton: [Rates.Rate],
                       usdt: [Rates.Rate],
                       completion: @escaping () -> Void) {
    updateState { [repository] _ in
      try? repository.saveRates(Rates(ton: ton, usdt: usdt, jettonRates: [:]))
      return StateUpdate(newState: State(tonRates: ton, usdtRates: usdt))
    } completion: { [weak self] state in
      guard let self else { return }
      self.sendEvent(.didUpdateRates(state: state))
      completion()
    }
  }
}

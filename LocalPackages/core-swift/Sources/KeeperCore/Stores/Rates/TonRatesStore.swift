import Foundation

public actor TonRatesStore {
  typealias ObservationClosure = (Event) -> Void
  public enum Event {
    case didUpdateRates(_ rates: [Rates.Rate])
  }
  
  private let repository: RatesRepository
  
  init(repository: RatesRepository) {
    self.repository = repository
  }
  
  func getTonRates() -> [Rates.Rate] {
    do {
      return try repository.getRates(jettons: []).ton
    } catch {
      return []
    }
  }
  
  func setTonRates(_ tonRates: [Rates.Rate]) {
    try? repository.saveRates(Rates(ton: tonRates, jettonsRates: []))
    observations.values.forEach { $0(.didUpdateRates(tonRates)) }
  }

  private var observations = [UUID: ObservationClosure]()
  
  public func addEventObserver<T: AnyObject>(_ observer: T,
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

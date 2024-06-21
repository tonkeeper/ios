import Foundation

public final class TonRatesStoreV2: Store<[Rates.Rate]> {
  
  private let repository: RatesRepository
  
  init(repository: RatesRepository) {
    self.repository = repository
    super.init(item: [])
    Task {
      await updateItem { _ in
        (try? repository.getRates(jettons: []).ton) ?? []
      }
    }
  }
  
  func getRates() async -> [Rates.Rate] {
    await getItem()
  }
  
  func setRates(_ rates: [Rates.Rate]) async {
    await updateItem { [repository] _ in
      try? repository.saveRates(Rates(ton: rates, jettonsRates: []))
      return rates
    }
  }
}

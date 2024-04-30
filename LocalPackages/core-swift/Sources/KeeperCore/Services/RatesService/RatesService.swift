import Foundation

protocol RatesService {
  func getRates(jettons: [JettonInfo]) -> Rates
  func loadRates(jettons: [JettonInfo],
                 currencies: [Currency]) async throws -> Rates
}

final class RatesServiceImplementation: RatesService {
  private let api: API
  private let ratesRepository: RatesRepository
  
  init(api: API, 
       ratesRepository: RatesRepository) {
    self.api = api
    self.ratesRepository = ratesRepository
  }
  
  func getRates(jettons: [JettonInfo]) -> Rates {
    do {
      return try ratesRepository.getRates(jettons: jettons)
    } catch {
      return Rates(ton: [], jettonsRates: [])
    }
  }
  
  func loadRates(jettons: [JettonInfo],
                 currencies: [Currency]) async throws -> Rates {
    let rates = try await api.getRates(
      jettons: jettons,
      currencies: currencies
    )
    try? ratesRepository.saveRates(rates)
    return rates
  }
}

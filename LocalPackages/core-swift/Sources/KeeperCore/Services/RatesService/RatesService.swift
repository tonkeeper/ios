import Foundation

public protocol RatesService {
    func loadRates(
        jettons: [String],
        currencies: [Currency]
    ) async throws -> Rates
}

final class RatesServiceImplementation: RatesService {
    private let api: API
    private let ratesRepository: RatesRepository

    init(
        api: API,
        ratesRepository: RatesRepository
    ) {
        self.api = api
        self.ratesRepository = ratesRepository
    }

    func loadRates(
        jettons: [String],
        currencies: [Currency]
    ) async throws -> Rates {
        let rates = try await api.getRates(
            currencies: currencies,
            jettons: jettons
        )
        try? ratesRepository.saveRates(rates)
        return rates
    }
}

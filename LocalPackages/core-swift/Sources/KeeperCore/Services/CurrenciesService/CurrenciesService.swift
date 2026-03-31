import Foundation

public protocol CurrenciesService {
    func loadCurrencies() async throws -> [RemoteCurrency]
    func clearCachedCurrencies()
}

final class CurrenciesServiceImplementation: CurrenciesService {
    private let api: CurrenciesAPI
    private let repository: CurrenciesRepository
    private let currenciesCacheTTL: TimeInterval = 60 * 60

    init(api: CurrenciesAPI, repository: CurrenciesRepository) {
        self.api = api
        self.repository = repository
    }

    func loadCurrencies() async throws -> [RemoteCurrency] {
        if let cached = try? repository.getCurrencies(),
           Date().timeIntervalSince(cached.cachedAt) < currenciesCacheTTL
        {
            return cached.data
        }
        let result = try await api.loadCurrencies()
        try? repository.saveCurrencies(result)
        return result
    }

    func clearCachedCurrencies() {
        repository.clearCache()
    }
}

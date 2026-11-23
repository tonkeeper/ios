import Foundation
import TKLogging

public protocol RatesService {
    func loadRates(jettons: [String], currencies: [Currency]) async throws -> Rates
}

enum RatesServiceError: Error {
    /// Nothing cached, and the previous attempt failed too recently to try again.
    case unavailable
}

/// Owns `/v2/rates` traffic: serves a still-fresh response from memory, coalesces concurrent callers
/// onto one request, and holds off briefly after a failure.
actor RatesServiceImplementation: RatesService {
    typealias FetchRates = (_ jettons: [String], _ currencies: [Currency]) async throws -> Rates

    private struct Key: Hashable {
        let jettons: [String]
        let currencies: [String]
    }

    private struct Cached {
        let rates: Rates
        let date: Date
    }

    private let fetchRates: FetchRates
    private let ratesRepository: RatesRepository?
    private let servesStaleRatesOnFailure: Bool
    private let freshnessInterval: TimeInterval
    private let failureRetryInterval: TimeInterval
    private let now: @Sendable () -> Date

    private var cached = [Key: Cached]()
    private var lastFailureDate = [Key: Date]()
    private var loads = [Key: Task<Rates, Error>]()

    init(
        fetchRates: @escaping FetchRates,
        ratesRepository: RatesRepository?,
        servesStaleRatesOnFailure: Bool = true,
        freshnessInterval: TimeInterval = 30,
        failureRetryInterval: TimeInterval = 5,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fetchRates = fetchRates
        self.ratesRepository = ratesRepository
        self.servesStaleRatesOnFailure = servesStaleRatesOnFailure
        self.freshnessInterval = freshnessInterval
        self.failureRetryInterval = failureRetryInterval
        self.now = now
    }

    /// Balance displays allow a stale payload during an outage; risk totals opt out.
    func loadRates(jettons: [String], currencies: [Currency]) async throws -> Rates {
        let key = Key(
            jettons: jettons.sorted(),
            currencies: currencies.map(\.code).sorted()
        )

        if let cached = cached[key], now().timeIntervalSince(cached.date) < freshnessInterval {
            return cached.rates
        }

        if let failureDate = lastFailureDate[key],
           now().timeIntervalSince(failureDate) < failureRetryInterval
        {
            guard servesStaleRatesOnFailure, let cached = cached[key] else { throw RatesServiceError.unavailable }
            return cached.rates
        }

        do {
            return try await load(key: key, jettons: jettons, currencies: currencies).value
        } catch {
            guard servesStaleRatesOnFailure, let cached = cached[key] else { throw error }
            return cached.rates
        }
    }

    private func load(
        key: Key,
        jettons: [String],
        currencies: [Currency]
    ) -> Task<Rates, Error> {
        if let load = loads[key] {
            return load
        }
        // Unstructured on purpose: cancelling one caller must not cancel a request the other
        // callers are waiting on.
        let load = Task {
            do {
                let rates = try await self.fetchRates(jettons, currencies)
                self.persist(rates)
                self.store(rates: rates, key: key)
                return rates
            } catch {
                self.storeFailure(key: key)
                throw error
            }
        }
        loads[key] = load
        return load
    }

    private func persist(_ rates: Rates) {
        do {
            try ratesRepository?.saveRates(rates)
        } catch {
            Log.tonAPI.w("failed to cache rates on disk", extraInfo: ["error": "\(error)"])
        }
    }

    private func store(rates: Rates, key: Key) {
        loads.removeValue(forKey: key)
        lastFailureDate.removeValue(forKey: key)
        cached[key] = Cached(rates: rates, date: now())
    }

    /// Only the failure timestamp moves: a cached payload stays available, and stays as stale as it is.
    private func storeFailure(key: Key) {
        loads.removeValue(forKey: key)
        lastFailureDate[key] = now()
    }
}

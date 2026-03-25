import Foundation
import TonAPI

public protocol BuySellMethodsService {
    func loadFiatMethods(countryCode: String?) async throws -> FiatMethods
}

final class BuySellMethodsServiceImplementation: BuySellMethodsService {
    private let api: TonkeeperAPI
    private let buySellMethodsRepository: BuySellMethodsRepository

    init(
        api: TonkeeperAPI,
        buySellMethodsRepository: BuySellMethodsRepository
    ) {
        self.api = api
        self.buySellMethodsRepository = buySellMethodsRepository
    }

    func loadFiatMethods(countryCode: String?) async throws -> FiatMethods {
        do {
            return try await api.loadFiatMethods(countryCode: countryCode)
        } catch {
            throw error
        }
    }
}

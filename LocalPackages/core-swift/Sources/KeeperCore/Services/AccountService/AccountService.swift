
import Foundation
import TonAPI
import TonSwift

protocol AccountService {
    func loadAccount(network: Network, address: Address) async throws -> Account
    func loadAccount(network: Network, domain: String) async throws -> Account
}

final class AccountServiceImplementation: AccountService {
    private let apiProvider: APIProvider

    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }

    func loadAccount(network: Network, address: Address) async throws -> Account {
        return try await apiProvider.api(network).getAccountInfo(accountId: address.toRaw())
    }

    func loadAccount(network: Network, domain: String) async throws -> Account {
        return try await apiProvider.api(network).getAccountInfo(accountId: domain)
    }
}

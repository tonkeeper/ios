
import Foundation
import TonSwift
import TonAPI

protocol AccountService {
  func loadAccount(isTestnet: Bool, address: Address) async throws -> Account
}

final class AccountServiceImplementation: AccountService {
  
  private let apiProvider: APIProvider
  
  init(apiProvider: APIProvider) {
    self.apiProvider = apiProvider
  }
  
  func loadAccount(isTestnet: Bool, address: Address) async throws -> Account {
    let account = try await apiProvider.api(isTestnet).getAccountInfo(address: address.toRaw())
    return account
  }
}

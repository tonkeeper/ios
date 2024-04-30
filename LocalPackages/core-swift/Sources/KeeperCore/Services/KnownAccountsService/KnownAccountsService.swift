import Foundation

protocol KnownAccountsService {
  func loadKnownAccounts() async throws -> [KnownAccount]
  func getKnownAccounts() throws -> [KnownAccount]
}

final class KnownAccountsServiceImplementation: KnownAccountsService {
  private let session: URLSession
  private let knownAccountsRepository: KnownAccountsRepository
  private let jsonDecoder = JSONDecoder()
  
  init(session: URLSession,
       knownAccountsRepository: KnownAccountsRepository) {
    self.session = session
    self.knownAccountsRepository = knownAccountsRepository
  }
  
  func loadKnownAccounts() async throws -> [KnownAccount] {
    let response = try await session.data(from: .knownAccountsUrl)
    let knownAccounts = try jsonDecoder.decode([KnownAccount].self, from: response.0)
    try? knownAccountsRepository.saveKnownAccounts(knownAccounts)
    return knownAccounts
  }
  
  func getKnownAccounts() throws -> [KnownAccount] {
    knownAccountsRepository.getKnownAccounts()
  }
}

private extension URL {
  static var knownAccountsUrl: URL {
    URL(string: "https://raw.githubusercontent.com/tonkeeper/ton-assets/main/accounts.json")!
  }
}

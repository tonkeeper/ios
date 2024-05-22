import Foundation
import TonSwift
import TonAPI
import BigInt

protocol JettonService {
  func loadAvailable(wallet: Wallet) async throws -> [JettonInfo]
}

final class JettonServiceImplementation: JettonService {
  
  private let apiProvider: APIProvider
  
  init(apiProvider: APIProvider) {
    self.apiProvider = apiProvider
  }

  // TODO: - Enrich API
  // - to provide whitelisted or suggested jettons
  // - to search with token name or symbol
  // - to search all avaiable for swap (maybe separate Service, working with STON.fi API)
  func loadAvailable(wallet: Wallet) async throws -> [JettonInfo] {
    return try await apiProvider.api(wallet.isTestnet).getJettons(limit: 1000, offset: 0)
  }
}

import Foundation
import TonSwift
import TonAPI
import BigInt

protocol JettonBalanceService {
  func loadJettonsBalance(wallet: Wallet, currency: Currency) async throws -> [JettonBalance]
}

final class JettonBalanceServiceImplementation: JettonBalanceService {
  
  private let apiProvider: APIProvider
  
  init(apiProvider: APIProvider) {
    self.apiProvider = apiProvider
  }
  
  func loadJettonsBalance(wallet: Wallet, currency: Currency) async throws -> [JettonBalance] {
    let currencies = Array(Set([Currency.USD, Currency.TON, currency]))
    let tokensBalance = try await apiProvider.api(wallet.isTestnet).getAccountJettonsBalances(
      address: wallet.address,
      currencies: currencies
    )
    let filtered = tokensBalance.filter { $0.item.jettonInfo.verification != .blacklist }
    return filtered
  }
}

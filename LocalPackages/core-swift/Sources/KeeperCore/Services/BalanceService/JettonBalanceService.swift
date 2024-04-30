import Foundation
import TonSwift
import TonAPI
import BigInt

protocol JettonBalanceService {
  func loadJettonsBalance(address: Address, currency: Currency) async throws -> [JettonBalance]
}

final class JettonBalanceServiceImplementation: JettonBalanceService {
  
  private let api: API
  
  init(api: API) {
    self.api = api
  }
  
  func loadJettonsBalance(address: Address, currency: Currency) async throws -> [JettonBalance] {
    let currencies = Array(Set([Currency.USD, Currency.TON, currency]))
    let tokensBalance = try await api.getAccountJettonsBalances(address: address, currencies: currencies)
    return tokensBalance
  }
}

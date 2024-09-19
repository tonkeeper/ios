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
    let sortedTokensBalance = tokensBalance.sorted {
      if $0.item.jettonInfo.address == JettonMasterAddress.tonUSDT {
        return true
      }
      if $1.item.jettonInfo.address == JettonMasterAddress.tonUSDT {
        return false
      }
      switch ($0.item.jettonInfo.verification, $1.item.jettonInfo.verification) {
      case (.whitelist, .whitelist):
        return true
      case (.whitelist, _):
        return true
      case (_, .whitelist):
        return false
      default:
        return true
      }
    }
    return sortedTokensBalance
  }
}

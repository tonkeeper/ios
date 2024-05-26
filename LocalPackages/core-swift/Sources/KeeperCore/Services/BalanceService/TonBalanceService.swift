import Foundation
import TonSwift
import TonAPI

protocol TonBalanceService {
  func loadBalance(wallet: Wallet) async throws -> TonBalance
}

final class TonBalanceServiceImplementation: TonBalanceService {
  
  private let apiProvider: APIProvider
  
  init(apiProvider: APIProvider) {
    self.apiProvider = apiProvider
  }
  
  func loadBalance(wallet: Wallet) async throws -> TonBalance {
    let account = try await apiProvider.api(wallet.isTestnet).getAccountInfo(address: wallet.address.toRaw())
    let tonBalance = TonBalance(amount: account.balance)
    return tonBalance
  }
}

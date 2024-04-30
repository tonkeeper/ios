import Foundation
import TonSwift
import TonAPI

protocol TonBalanceService {
  func loadBalance(address: Address) async throws -> TonBalance
}

final class TonBalanceServiceImplementation: TonBalanceService {
  
  private let api: API
  
  init(api: API) {
    self.api = api
  }
  
  func loadBalance(address: Address) async throws -> TonBalance {
    let account = try await api.getAccountInfo(address: address.toRaw())
    let tonBalance = TonBalance(amount: account.balance)
    return tonBalance
  }
}

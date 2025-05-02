import Foundation
import TronSwift
import TronSwiftAPI
import BigInt

public protocol TronBalanceService {
  func loadBalance(address: Address) async throws -> TronBalance
}

public final class TronBalanceServiceImplementation: TronBalanceService {
  
  private let api: TronSwiftAPI.API
  
  public init(api: TronSwiftAPI.API) {
    self.api = api
  }
  
  public func loadBalance(address: Address) async throws -> TronBalance {
    let value = try await api.tronUSDTBalance(owner: address, network: .mainnet)
    let balance = TronBalance(amount: value)
    return balance
  }
}

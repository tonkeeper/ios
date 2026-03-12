import BigInt
import Foundation
import TronSwift
import TronSwiftAPI

public protocol TronBalanceService {
    func loadBalance(address: Address) async throws -> TronBalance
}

public final class TronBalanceServiceImplementation: TronBalanceService {
    private let api: TronSwiftAPI.API

    public init(api: TronSwiftAPI.API) {
        self.api = api
    }

    public func loadBalance(address: Address) async throws -> TronBalance {
        let value = try await api.tronUSDTBalance(owner: address)
        return TronBalance(amount: value)
    }
}

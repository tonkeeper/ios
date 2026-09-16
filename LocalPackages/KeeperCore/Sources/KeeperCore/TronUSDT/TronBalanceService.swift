import BigInt
import Foundation
import TKLogging
import TronSwift
import TronSwiftAPI

public protocol TronBalanceService {
    func loadBalance(address: Address) async throws -> TronBalance
    func loadAccountBalances(address: Address) async throws -> TronBalance
    func loadAccountBalancesBatch(addresses: [Address]) async throws -> [String: TronBalance]
}

final class TronBalanceServiceImplementation: TronBalanceService {
    private let api: TronApi

    init(api: TronApi) {
        self.api = api
    }

    func loadBalance(address: Address) async throws -> TronBalance {
        let balances = try await api.tronBalances(owner: address)
        return TronBalance(
            amount: balances.usdtAmount,
            trxAmount: balances.trxAmount
        )
    }

    func loadAccountBalances(address: Address) async throws -> TronBalance {
        let balances = try await api.tronAccountBalances(owner: address)
        return TronBalance(
            amount: balances.usdtAmount,
            trxAmount: balances.trxAmount
        )
    }

    func loadAccountBalancesBatch(addresses: [Address]) async throws -> [String: TronBalance] {
        try await api.tronAccountBalancesBatch(owners: addresses)
            .mapValues { TronBalance(amount: $0.usdtAmount, trxAmount: $0.trxAmount) }
    }
}
